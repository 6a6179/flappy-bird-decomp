#!/usr/bin/env python3
"""Compile the source and check complete functions against the supplied Flap executable.

Rows in matches/*.tsv contain architecture, original VM address, byte count,
source file, exact Mach-O symbol name, optional additional compiler flags,
and an optional historical compiler name (llvm33, apple421, apple500, apple502 or apple600).
A count may describe the compiler body or the original function slot including
alignment. Coverage credits compiler-emitted body bytes only. Darwin's nlist
has no symbol size, so use Clang's DWARF subprogram extent for the rebuilt
body and the executable's LC_FUNCTION_STARTS for the original slot.
"""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shlex
import shutil
import struct
import subprocess
import sys
from tempfile import TemporaryDirectory
from typing import NamedTuple
import zipfile


ROOT = Path(__file__).resolve().parents[1]
EXECUTABLE = "Payload/Flap.app/flap"
CPU_ARM = 12
ARCHES = {9: "armv7", 11: "armv7s"}
# Name, setup script and version string of the compiler used by a manifest.
HISTORICAL = {
    "llvm33": ("get_llvm33.py", "clang version 3.3 "),
    "apple421": ("get_apple_clang.py --release 421", "clang-421.11.65"),
    "apple500": ("get_apple_clang.py", "LLVM version 3.3"),
    "apple502": ("get_apple502.py", "clang-500.2.79"),
    "apple600": ("get_apple600.py", "clang-600.0.57"),
}
SLICE_SHA256 = {
    "armv7": "7f512cb352e668f7581c9a328fb406192227d3f32501f5b78c2dacd4976172bc",
    "armv7s": "50fde71ae6852388969fe2f241e98cdd5526e9e0695e2bc05cb43f154b368153",
}


def name(field):
    return field.split(b"\0", 1)[0].decode()


class Section(NamedTuple):
    index: int
    segment: str
    name: str
    addr: int
    size: int
    offset: int
    align: int
    reloff: int
    nreloc: int


class Symbol(NamedTuple):
    addr: int
    section: int
    description: int


class Image:
    """The 32-bit little-endian Mach-O fields needed by the comparison."""

    def __init__(self, data):
        self.data = data
        magic, cpu, sub, self.filetype, ncmds, _, _ = struct.unpack_from("<7I", data)
        if magic != 0xfeedface or cpu != CPU_ARM:
            raise ValueError("expected a 32-bit ARM Mach-O")
        self.arch = ARCHES[sub & 0x00ffffff]
        self.sections = []
        self.symbols = {}
        self.starts = {}
        self.literal_ends = set()
        self.literal_ranges = []
        start_table = None
        data_in_code = None
        entry_offset = None
        text_base = None
        table = None
        pos = 28
        for _ in range(ncmds):
            cmd, size = struct.unpack_from("<II", data, pos)
            if size < 8 or pos + size > len(data):
                raise ValueError("invalid Mach-O load command")
            if cmd == 1:  # LC_SEGMENT
                seg, base, _, _, _, _, _, count, _ = struct.unpack_from("<16s8I", data, pos + 8)
                if name(seg) == "__TEXT":
                    text_base = base
                for index in range(count):
                    section = struct.unpack_from("<16s16s9I", data, pos + 56 + index * 68)
                    sect_name, seg_name, addr, length, offset, align, reloff, nreloc, _, _, _ = section
                    self.sections.append(Section(len(self.sections) + 1, name(seg_name),
                                                 name(sect_name), addr, length, offset,
                                                 align, reloff, nreloc))
            elif cmd == 2:  # LC_SYMTAB
                table = struct.unpack_from("<4I", data, pos + 8)
            elif cmd == 0x26:  # LC_FUNCTION_STARTS
                start_table = struct.unpack_from("<II", data, pos + 8)
            elif cmd == 0x29:  # LC_DATA_IN_CODE
                data_in_code = struct.unpack_from("<II", data, pos + 8)
            elif cmd == 0x80000028:  # LC_MAIN
                entry_offset, = struct.unpack_from("<Q", data, pos + 8)
            pos += size
        text_sections = [s for s in self.sections if (s.segment, s.name) == ("__TEXT", "__text")]
        if len(text_sections) != 1:
            raise ValueError("expected one __TEXT,__text")
        self.text = text_sections[0]
        if self.filetype == 1 and self.text.size == 0:
            # Darwin clang emits C++ static initialization thunks into their
            # own input section. ld places them in the executable's __text.
            init = [s for s in self.sections if (s.segment, s.name) == ("__TEXT", "__StaticInit")]
            if len(init) == 1:
                self.text = init[0]
        if data_in_code:
            offset, size = data_in_code
            for entry in range(offset, offset + size, 8):
                file_offset, length, kind = struct.unpack_from("<IHH", data, entry)
                # MH_OBJECT offsets are in the object layout. In the linked
                # executable they are file offsets relative to the Mach header.
                address = file_offset if self.filetype == 1 else self.text.addr + file_offset - self.text.offset
                if self.text.addr <= address and address + length <= self.text.addr + self.text.size:
                    self.literal_ranges.append((address, address + length))
                    if kind == 1:  # DICE_KIND_DATA
                        self.literal_ends.add(address + length)
        self.entry = None if entry_offset is None else text_base + entry_offset
        if table:
            symoff, count, stroff, strsize = table
            strings = data[stroff:stroff + strsize]
            for offset in range(symoff, symoff + count * 12, 12):
                idx, kind, sect, desc, value = struct.unpack_from("<IBBHI", data, offset)
                if kind & 0xe0 or kind & 0x0e != 0x0e:  # skip STABS and non-section symbols
                    continue
                label = strings[idx:strings.index(b"\0", idx)].decode()
                self.symbols[label] = Symbol(value, sect, desc)
        if start_table:
            if text_base is None:
                raise ValueError("function starts without a __TEXT base")
            offset, size = start_table
            address = text_base
            delta = shift = 0
            for byte in data[offset:offset + size]:
                delta |= (byte & 127) << shift
                if byte & 128:
                    shift += 7
                    continue
                if delta == 0:
                    break
                address += delta
                aligned = address & ~1
                if self.text.addr <= aligned < self.text.addr + self.text.size:
                    self.starts[aligned] = bool(address & 1)
                delta = shift = 0
        starts = sorted(self.starts)
        self.ends = dict(zip(starts, starts[1:] + [self.text.addr + self.text.size]))
        self.relocations = list(self._relocations())

    def text_bytes(self, addr, length):
        offset = addr - self.text.addr
        if offset < 0 or length < 0 or offset + length > self.text.size:
            raise ValueError(f"range {addr:#x}+{length} outside __text")
        return self.data[self.text.offset + offset:self.text.offset + offset + length]

    def _relocations(self):
        for i in range(self.text.nreloc):
            first, second = struct.unpack_from("<II", self.data, self.text.reloff + 8 * i)
            if first >> 31:  # scattered_relocation_info
                kind = (first >> 24) & 15
                width = (first >> 28) & 3
                offset = first & 0xffffff
            else:
                kind = second >> 28
                width = (second >> 25) & 3
                offset = first
            if kind == 1:  # ARM_RELOC_PAIR has an addend, not an instruction address
                continue
            length = 4 if kind in (8, 9) else 1 << width  # HALF uses width for flags
            yield self.text.addr + offset, length

    def has_relocation(self, start, length):
        return any(pos < start + length and pos + size > start for pos, size in self.relocations)


def original_images(ipa):
    with zipfile.ZipFile(ipa) as archive:
        binary = archive.read(EXECUTABLE)
    magic, count = struct.unpack_from(">II", binary)
    if magic != 0xcafebabe:
        raise ValueError("expected the universal Flappy Bird executable")
    images = {}
    for i in range(count):
        cpu, subtype, offset, size, _ = struct.unpack_from(">5I", binary, 8 + 20 * i)
        arch = ARCHES.get(subtype & 0x00ffffff)
        if cpu != CPU_ARM or arch is None:
            continue
        data = binary[offset:offset + size]
        if hashlib.sha256(data).hexdigest() != SLICE_SHA256[arch]:
            raise ValueError(f"{arch} executable differs from the the supplied Flap executable reference")
        image = Image(data)
        if arch != image.arch or not image.starts or image.filetype != 2:
            raise ValueError(f"invalid reference slice {arch}")
        images[arch] = image
    if images.keys() != SLICE_SHA256.keys():
        raise ValueError("the IPA must contain both reference slices")
    return images


def find_tool(tool):
    if shutil.which("xcrun"):
        return subprocess.check_output(["xcrun", "--find", tool], text=True).strip()
    path = shutil.which(tool)
    if not path:
        raise ValueError(f"missing {tool} (provided with Xcode command-line tools)")
    return path


def dwarf_extents(path, dwarfdump):
    """Read only concrete, contiguous subprogram entries. DWARF v2 high_pc is absolute."""
    output = subprocess.check_output([dwarfdump, "--debug-info", str(path)], text=True)
    extents = {}
    # Each DIE begins with a hexadecimal offset, including each child DIE.
    for entry in re.split(r"^0x[0-9a-fA-F]+:\s*", output, flags=re.M):
        if not entry.startswith("DW_TAG_subprogram\n"):
            continue
        low = re.search(r"DW_AT_low_pc\s+\((0x[\da-fA-F]+)\)", entry)
        high = re.search(r"DW_AT_high_pc\s+\((0x[\da-fA-F]+)\)", entry)
        if low and high:
            start = int(low[1], 16)
            end = int(high[1], 16)
            if start in extents and extents[start] != end:
                raise ValueError(f"ambiguous DWARF function at {start:#x}")
            extents[start] = end
    return extents


class Match(NamedTuple):
    arch: str
    address: int
    length: int
    source: Path
    symbol: str
    flags: tuple
    toolchain: str = "system"


def read_manifests():
    for path in sorted((ROOT / "matches").glob("*.tsv")):
        for lineno, line in enumerate(path.read_text().splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            try:
                fields = line.split("\t")
                arch, address, length, source, symbol = fields[:5]
                toolchain = fields[6] if len(fields) == 7 else "system"
                if len(fields) not in (5, 6, 7) or arch not in SLICE_SHA256 or (toolchain != "system" and toolchain not in HISTORICAL):
                    raise ValueError("expected architecture, address, length, source, symbol, optional flags and toolchain")
                yield Match(arch, int(address, 0), int(length), ROOT / source, symbol,
                            tuple(shlex.split(fields[5])) if len(fields) >= 6 else (), toolchain)
            except ValueError as exc:
                raise ValueError(f"{path.name}:{lineno}: {exc}") from exc


def compile_source(row, path, clang, dwarfdump):
    assembler = ["-integrated-as"] if row.toolchain in HISTORICAL else []
    subprocess.run([clang, "-target", f"{row.arch}-apple-ios7.0", "-mthumb", "-Os",
                    "-ffreestanding", "-isysroot", "/", *assembler, *row.flags, "-gdwarf-2", "-c",
                    str(row.source), "-o", str(path)], check=True, cwd=ROOT)
    image = Image(path.read_bytes())
    if image.arch != row.arch or image.filetype != 1:
        raise ValueError(f"compiler did not emit an {row.arch} relocatable object")
    return image, dwarf_extents(path, dwarfdump)


def terminal_thumb_instruction(image, end):
    last, = struct.unpack("<H", image.text_bytes(end - 2, 2))
    # BX Rm or POP {..., pc}.
    if last & 0xff87 == 0x4700 or last & 0xff00 == 0xbd00:
        return True
    if end - image.text.addr < 4:
        return False
    first, = struct.unpack("<H", image.text_bytes(end - 4, 2))
    # Unconditional B.W or LDMIA.W sp!, {..., pc}.
    if ((first & 0xf800 == 0xf000 and last & 0xd000 == 0x9000)
            or (first == 0xe8bd and last & 0x8000 != 0)):
        return True
    if first & 0xf800 == 0xf000 and last & 0xd001 == 0xc000:  # T2 BLX
        from linkmatch import reference_layout
        sign = first >> 10 & 1
        i1 = 1 ^ sign ^ (last >> 13 & 1)
        i2 = 1 ^ sign ^ (last >> 11 & 1)
        delta = (-(sign << 24) | i1 << 23 | i2 << 22 | (first & 0x3ff) << 12
                 | (last & 0x7fe) << 1)
        destination = (end & ~3) + delta
        return destination in reference_layout(image.data).targets.get(("stub", "___stack_chk_fail"), ())
    return False


def alignment_fill(image, start, end, thumb):
    if start == end:
        return True
    # Only accept ARM/Thumb NOPs sufficient to align the next function, with
    # an alignment supported by the containing section. Zeroes may be data.
    gap = end - start
    if gap >= 1 << image.text.align:
        return False
    unit = 2 if thumb else 4
    nops = (b"\x00\xbf", b"\xc0\x46") if thumb else (b"\x00\xf0\x20\xe3", b"\x00\x00\xa0\xe1")
    fill = image.text_bytes(start, gap)
    if gap % unit or any(fill[i:i + unit] not in nops for i in range(0, gap, unit)):
        return False
    aligns = (1 << exponent for exponent in range(1, image.text.align + 1))
    if any(end % align == 0 and gap < align for align in aligns):
        return True
    # ld64 can leave input-subsection padding even if the next function no
    # longer lands on that boundary. Accept only its canonical Thumb fill
    # after a control transfer or the end of a linker-identified literal.
    if thumb and start % 4 == 2 and fill.startswith(b"\x00\xbf"):
        fill = fill[2:]  # assembler NOP up to the next 4-byte boundary
    return (thumb and fill == b"\xc0\x46" * (len(fill) // 2)
            and (start in image.literal_ends or terminal_thumb_instruction(image, start)))


def verify_function(row, original, rebuilt, extents, *, return_body=False):
    addr = row.address
    if addr not in original.starts:
        raise ValueError("original address must be an aligned LC_FUNCTION_STARTS entry")
    if row.symbol == "_main" and (addr | original.starts[addr]) != original.entry:
        raise ValueError("original address differs from LC_MAIN entry point")
    symbol = rebuilt.symbols.get(row.symbol)
    if symbol is None or symbol.section != rebuilt.text.index:
        raise ValueError("no such symbol in compiled __text")
    if bool(symbol.description & 8) != original.starts[addr]:
        raise ValueError("ARM/Thumb state differs")
    start = symbol.addr & ~1
    if start not in extents:
        raise ValueError("missing compiler-reported function extent")
    length = extents[start] - start
    slot = original.ends[addr] - addr
    if length <= 0 or row.length not in (length, slot) or length > slot:
        raise ValueError(f"size mismatch: manifest {row.length}, compiler {length}, original slot {slot}")
    if not alignment_fill(original, addr + length, addr + slot, original.starts[addr]):
        raise ValueError(f"compiler body ({length}) leaves original instructions or data in slot ({slot})")
    if rebuilt.has_relocation(start, length):
        from linkmatch import link_function
        body = link_function(rebuilt.data, original.data, start, addr, length)
    else:
        body = rebuilt.text_bytes(start, length)
    expected = original.text_bytes(addr, length)
    if len(body) != length:
        raise ValueError("relocation handler changed body length")
    if body != expected:
        idx = next(i for i, (a, b) in enumerate(zip(body, expected)) if a != b)
        raise ValueError(f"byte differs at +{idx:#x}: compiler {body[idx]:02x}, original {expected[idx]:02x}")
    return body if return_body else length


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ipa", type=Path, default=ROOT / "Flappy Bird v1.2.ipa")
    parser.add_argument("--verbose", "-v", action="store_true", help="print each verified function")
    parser.add_argument("--arch", choices=sorted(SLICE_SHA256), help="verify only this architecture")
    for key in HISTORICAL:
        parser.add_argument("--" + key, type=Path, metavar="CLANG",
                            help=f"{key} compiler executable (also {key.upper()}_CLANG)")
    parser.add_argument("--rebuild", type=Path, metavar="OUTPUT",
                        help="write the reconstructed universal executable or a byte-identical .ipa")
    args = parser.parse_args()
    if args.rebuild and args.arch:
        parser.error("--rebuild requires both architectures")
    originals = original_images(args.ipa)
    arches = [args.arch] if args.arch else sorted(originals)
    rows = [row for row in read_manifests() if row.arch in arches]
    from admob_fragments import declared_fragments, verify_fragments
    fragment_rows = [(row, moves) for row, moves in declared_fragments(ROOT) if row.arch in arches]
    if not rows:
        raise ValueError("no function matches declared")
    dwarfdump = find_tool("llvm-dwarfdump")
    clangs = {}
    for toolchain in sorted({row.toolchain for row in rows} | {row.toolchain for row, _ in fragment_rows}):
        if toolchain in HISTORICAL:
            setup, expected = HISTORICAL[toolchain]
            clang = getattr(args, toolchain) or os.environ.get(toolchain.upper() + "_CLANG")
            clang = Path(clang or ROOT / ".toolchains" / toolchain / "bin/clang").resolve()
            if not clang.is_file():
                raise ValueError(f"run python3 tools/{setup} or set --{toolchain}")
        else:
            clang = find_tool("clang")
        version = subprocess.check_output([clang, "--version"], text=True).splitlines()[0]
        if toolchain in HISTORICAL and expected not in version:
            raise ValueError(f"expected {toolchain} ({expected.strip()}), found {version}")
        clangs[toolchain] = clang
        print(version, flush=True)
    from arm_padding import CodePadding
    from assembly import complete_text
    from linker_islands import LinkerIslands
    islands = {arch: LinkerIslands(originals[arch]) for arch in arches}
    padding = {arch: CodePadding(originals[arch], clangs) for arch in arches}
    failures = 0
    seen = set()
    compiled = {arch: {} for arch in arches}
    fragments = {arch: {} for arch in arches}
    logical_lengths = {arch: [] for arch in arches}
    with TemporaryDirectory(prefix="flap-verify-") as work:
        # Independently validate method identities, including same-byte methods
        # such as retain/release stubs that would also match at other addresses.
        from decompile import method_names
        methods = {}
        for arch in arches:
            thin = Path(work) / arch
            thin.write_bytes(originals[arch].data)
            methods[arch] = method_names(thin)
        cache = {}

        def compiled_object(row):
            key = (row.arch, row.source, row.flags, row.toolchain)
            if key not in cache:
                objpath = Path(work) / f"{len(cache)}.o"
                cache[key] = compile_source(row, objpath, clangs[row.toolchain], dwarfdump)
            return cache[key]

        for row in rows:
            label = f"{row.arch} {row.address:#010x} {row.symbol}"
            try:
                if (row.arch, row.address) in seen:
                    raise ValueError("duplicate original function address")
                seen.add((row.arch, row.address))
                original = originals[row.arch]
                if row.symbol.startswith(("-[", "+[")):
                    imp = row.address | original.starts.get(row.address, False)
                    owner = methods[row.arch].get(imp)
                    # ld64 can attach a category's methods to the base class
                    # method list. Retain the class, dispatch kind and selector.
                    base = re.sub(r"^(\+|-)(\[[^ (]+)\([^() ]+\) ", r"\1\2 ", row.symbol)
                    if owner not in (row.symbol, base):
                        raise ValueError("class/selector does not map to this address in original Objective-C metadata")
                rebuilt, extents = compiled_object(row)
                body = verify_function(row, original, rebuilt, extents, return_body=True)
                islands[row.arch].observe(row, rebuilt, len(body))
                padding[row.arch].observe(row, rebuilt, extents)
            except (ValueError, ImportError, subprocess.CalledProcessError) as exc:
                failures += 1
                print(f"FAIL {label}: {exc}", file=sys.stderr)
                continue
            compiled[row.arch][row.address] = body
            if args.verbose:
                print(f"MATCH {label} ({len(body)} bytes)")
        for row, moves in fragment_rows:
            try:
                parts, length = verify_fragments(row, moves, originals[row.arch], *compiled_object(row))
                if parts.keys() & (compiled[row.arch].keys() | fragments[row.arch].keys()):
                    raise ValueError("outlined function overlaps another claimed entry")
                fragments[row.arch].update(parts)
                logical_lengths[row.arch].append(length)
            except (ValueError, ImportError, subprocess.CalledProcessError) as exc:
                failures += 1
                print(f"FAIL {row.arch} {row.symbol}: {exc}", file=sys.stderr)
    for arch in arches:
        image = originals[arch]
        # ObjectAL immediately follows the app in both pinned executables.
        # A missing game function must fail the build even if its archived
        # assembly would otherwise reproduce the same executable.
        audio_start, = [address & ~1 for address, selector in methods[arch].items()
                        if selector == "-[OALAction init]"]
        game_entries = {address for address in image.starts if address < audio_start}
        missing = sorted(game_entries - compiled[arch].keys())
        print(f"{arch}: {len(game_entries) - len(missing)}/{len(game_entries)} game and iOS "
              "functions matched from compiled source")
        if missing:
            failures += len(missing)
            print(f"FAIL {arch} game functions missing from compiled source: "
                  + ", ".join(hex(address) for address in missing), file=sys.stderr)
        sizes = [len(body) for body in compiled[arch].values()]
        print(f"{arch}: {len(sizes)}/{len(image.starts)} contiguous source matches, "
              f"{sum(sizes)}/{image.text.size} __text bytes ({sum(sizes)/image.text.size:.3%})")
        if fragments[arch]:
            print(f"{arch}: {len(logical_lengths[arch])} C functions with vendor layout changes "
                  f"({sum(logical_lengths[arch])} compiler bytes), "
                  f"{len(fragments[arch])} original entries after vendor layout")
            compiled[arch].update(fragments[arch])
        try:
            island_bodies = islands[arch].verify()
            if compiled[arch].keys() & island_bodies.keys():
                raise ValueError("linker islands overlap compiled source")
            print(f"{arch}: {len(island_bodies)} linker-generated Thumb-to-ARM islands "
                  f"({sum(map(len, island_bodies.values()))} __text bytes)")
            compiled[arch].update(island_bodies)
            compiled[arch], fill_bytes = padding[arch].complete(compiled[arch], game_entries)
            print(f"{arch}: {fill_bytes} assembler and linker alignment bytes")
            generated_bytes = len(complete_text(image, compiled[arch]))
            print(f"{arch}: {len(compiled[arch])}/{len(image.starts)} entries reproduced from source "
                  f"and generated layout, {generated_bytes}/{image.text.size} __text bytes "
                  f"({generated_bytes / image.text.size:.3%})")
        except ValueError as error:
            failures += 1
            print(f"FAIL {arch} generated layout: {error}", file=sys.stderr)
    if args.rebuild and not failures:
        from rebuild import write_output
        write_output(args.ipa, args.rebuild, originals, compiled)
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, struct.error, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        sys.exit(f"verify: {error}")
