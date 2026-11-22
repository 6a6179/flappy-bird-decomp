#!/usr/bin/env python3
"""Generate readable, fixed-layout ARM assembly and prove it reassembles exactly."""
import argparse
from dataclasses import dataclass
import gzip
from itertools import groupby
from pathlib import Path
import re
import subprocess
import tempfile

from assembly import compile_text
from decompile import method_names
from verify import ROOT, find_tool, original_images


@dataclass
class Line:
    addr: int
    size: int
    thumb: bool
    statement: str
    comment: str = ""
    target: int | None = None
    literal: tuple[int, int] | None = None
    data: bool = False


def label(addr):
    return f"L{addr:08x}"


def metadata(objdump, binary, image):
    output = subprocess.check_output([objdump, "--macho", "--data-in-code", binary], text=True)
    regions = {}
    for offset, length, kind in re.findall(r"^0x([0-9a-f]+)\s+(\d+)\s+(\w+)$", output, re.M):
        addr = int(offset, 16) + image.text.addr - image.text.offset
        size = int(length)
        regions[addr] = (size, kind)
        if (addr + size) % 2:
            regions[addr + size] = (1, "Thumb alignment")

    output = subprocess.check_output([objdump, "--macho", "--indirect-symbols", binary], text=True)
    stubs = {int(addr, 16): name for addr, name in
             re.findall(r"^0x(\w+)\s+\d+\s+(\S+)$", output, re.M)}
    return regions, stubs


def code_lines(objdump, binary, image, start, end, thumb, stubs):
    cpu = "swift" if image.arch == "armv7s" else "cortex-a8"
    triple = ("thumb" if thumb else "arm") + "v7-apple-ios7"
    text = subprocess.check_output([
        objdump, "-d", "-z", "--triple=" + triple, "--mcpu=" + cpu,
        f"--start-address={start}", f"--stop-address={end}", binary
    ], text=True)
    pos = start
    for line in text.splitlines():
        match = re.match(r"^\s*([0-9a-f]+): ([0-9a-f ]+)\t(.+)", line)
        if not match:
            continue
        addr = int(match[1], 16)
        raw = b"".join(bytes.fromhex(word)[::-1] for word in match[2].split())
        if addr != pos or image.text_bytes(addr, len(raw)) != raw:
            raise ValueError(f"Disassembly lost byte alignment at {pos:#x}")
        pos += len(raw)
        instr, _, comment = match[3].partition("@")
        row = Line(addr, len(raw), thumb, " ".join(instr.split()))
        dest = re.search(r"0x([0-9a-f]+) <[^>]+>", row.statement)
        if dest:
            target = int(dest[1], 16)
            mnemonic = row.statement.split()[0]
            in_text = image.text.addr <= target < image.text.addr + image.text.size
            if in_text and not mnemonic.startswith("blx") and (thumb or mnemonic != "bl"):
                row.target = target
                operand = label(target)
            else:
                # Darwin's assembler emits branch relocations for ARM BL and interworking
                # calls to symbols. Their immediate form preserves the fixed-layout distance.
                offset = re.search(r"imm = (#[^ ]+)", comment.strip())
                if not offset:
                    raise ValueError(f"Missing branch displacement: {line}")
                operand = offset[1]
            row.statement = row.statement[:dest.start()] + operand + row.statement[dest.end():]
            row.comment = f"{target:#010x} {stubs.get(target, '')}".rstrip()
        lit = re.search(r"0x([0-9a-f]+) <", comment)
        if lit and re.match(r"(?:vldr|ldr)(?:\.w)? .*\[pc\b", row.statement):
            target = int(lit[1], 16)
            if image.text.addr <= target < image.text.addr + image.text.size:
                row.literal = (target, 8 if row.statement.startswith("vldr d") else 4)
                row.comment = f"literal at {target:#010x}"
        yield row
    if pos != end:
        raise ValueError(f"Disassembly of {start:#x} ended at {pos:#x}, expected {end:#x}")


def data_lines(image, start, length, kind, thumb):
    width = {"JUMP_TABLE8": 1, "JUMP_TABLE16": 2, "JUMP_TABLE32": 4,
             "DATA": 4, "PC-relative literal": 4, "Thumb alignment": 1}[kind]
    directive = {1: ".byte", 2: ".short", 4: ".long"}[width]
    if length % width:
        raise ValueError(f"Unaligned {kind} at {start:#x}")
    for addr in range(start, start + length, width):
        value = int.from_bytes(image.text_bytes(addr, width), "little")
        target = None
        if kind.startswith("JUMP_TABLE"):
            # TBB/TBH entries are unsigned halfword counts. ARM entries in this
            # image are signed byte offsets from the start of the dispatch table.
            scale = 2 if thumb else 1
            if not thumb and value & 0x80000000:
                value -= 1 << 32
            target = start + value * scale
            operand = f"({label(target)} - {label(start)})" + ("/2" if thumb else "")
        else:
            operand = f"0x{value:0{width * 2}x}"
        note = "LC_DATA_IN_CODE " + kind if kind in {"DATA", "JUMP_TABLE8", "JUMP_TABLE16", "JUMP_TABLE32"} else kind
        yield Line(addr, width, thumb, f"{directive} {operand}", note, target, data=True)


def disassemble(objdump, binary, image, regions, stubs):
    modes = {next(group)[0]: mode for mode, group in
             groupby(sorted(image.starts.items()), key=lambda entry: entry[1])}
    points = sorted({image.text.addr, image.text.addr + image.text.size, *modes, *regions,
                     *(addr + n for addr, (n, _) in regions.items())})
    thumb = None
    rows = []
    for start, end in zip(points, points[1:]):
        thumb = modes.get(start, thumb)
        if start in regions:
            size, kind = regions[start]
            if size != end - start:
                raise ValueError(f"Overlapping {kind} at {start:#x}")
            rows.extend(data_lines(image, start, size, kind, thumb))
        else:
            rows.extend(code_lines(objdump, binary, image, start, end, thumb, stubs))
    return rows


def generate(image, destination):
    objdump = find_tool("llvm-objdump")
    with tempfile.TemporaryDirectory(prefix="flap-listing-") as temp:
        scratch = Path(temp)
        binary = scratch / image.arch
        binary.write_bytes(image.data)
        regions, stubs = metadata(objdump, binary, image)
        rows = disassemble(objdump, binary, image, regions, stubs)
        # Some compiler helpers and the interworking veneers have literal pools
        # absent from LC_DATA_IN_CODE. Recover them from PC-relative load targets.
        marked = {pos for addr, (size, _) in regions.items() for pos in range(addr, addr + size)}
        for row in rows:
            if row.literal and row.literal[0] not in marked:
                addr, size = row.literal
                span = range(addr, addr + size)
                if addr % 2 or not marked.isdisjoint(span):
                    raise ValueError(f"Ambiguous literal pool at {addr:#x}")
                regions[addr] = (size, "PC-relative literal")
                marked.update(span)
        rows = disassemble(objdump, binary, image, regions, stubs)
        names = {raw & ~1: name for raw, name in method_names(binary).items()}
        labels = set(image.starts) | set(regions) | {r.target for r in rows if r.target is not None}
        addresses = {r.addr for r in rows}
        if labels - addresses:
            raise ValueError(f"Labels not on decoded boundaries: {sorted(labels - addresses)}")

        source = scratch / "code.s"
        with source.open("w") as out:
            out.write("@ Flappy Bird 1.2 fixed-layout __TEXT,__text. Comments give original VM addresses.\n")
            out.write(".syntax unified\n.text\n")
            mode = None
            for row in rows:
                if row.thumb != mode:
                    mode = row.thumb
                    out.write(".thumb\n" if mode else ".arm\n")
                if row.addr in image.starts:
                    name = names.get(row.addr, "")
                    out.write(f"\n@ Function 0x{row.addr:08x} {name}".rstrip() + "\n")
                if row.addr in labels:
                    out.write(label(row.addr) + ":\n")
                out.write(f"    {row.statement}  @ {row.addr:08x} {row.comment}".rstrip() + "\n")
        assembled = compile_text(image.arch, source, scratch)
        if assembled != image.text_bytes(image.text.addr, image.text.size):
            raise ValueError(f"{image.arch} code failed complete byte comparison")
        destination.mkdir(parents=True, exist_ok=True)
        path = destination / (image.arch + ".s.gz")
        with path.open("wb") as packed, gzip.GzipFile(filename="", fileobj=packed, mode="wb",
                                                        compresslevel=9, mtime=0) as stream:
            stream.write(source.read_bytes())
    instructions = [r for r in rows if not r.data]
    print(f"{image.arch}  {len(instructions)} mnemonics, {sum(r.size for r in instructions)} "
          f"instruction bytes of {image.text.size} section bytes  {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, default=ROOT / "Flappy Bird v1.2.ipa")
    parser.add_argument("--out", type=Path, default=ROOT / "assembly")
    parser.add_argument("--arch", choices=["armv7", "armv7s"], action="append")
    args = parser.parse_args()
    images = original_images(args.ipa)
    for arch in args.arch or images:
        generate(images[arch], args.out)


if __name__ == "__main__":
    main()
