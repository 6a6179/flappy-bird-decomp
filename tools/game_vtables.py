"""Link native game virtual tables from the typed definitions used by their constructors."""

from collections import defaultdict
import struct
import subprocess

from linkmatch import Layout, reference_layout
from verify import Image, ROOT, find_tool, read_manifests


# Number of virtual methods after the two ARM Itanium ABI header words.
# The node types share a C view with an optional fifth method. Only the
# classes that implement it have five physical slots in the executable.
TABLES = {
    "renderer.c": {"_engine_vtable": 11},
    "native.c": {"_sprite_vtable": 5, "_button_vtable": 4},
    "scene_numbers.c": {"_number_vtable": 4},
    "scene.c": {"_sparkle_vtable": 5, "_medal_vtable": 4, "_panel_vtable": 4,
                "_sparkle_pool_vtable": 4, "_number_pool_vtable": 4},
    "scene_overlays.c": {"_ready_vtable": 4, "_game_over_vtable": 4},
    "gameplay_init.c": {"_game_vtable": 11, "_game_font_vtable": 2, "_bird_vtable": 5},
}


def rebased_pointers(image, tmp):
    path = tmp / f"{image.arch}-vtables-reference"
    path.write_bytes(image.data)
    output = subprocess.check_output(
        [find_tool("llvm-objdump"), "--macho", "--rebase", str(path)], text=True
    )
    return {int(fields[2], 16) for line in output.splitlines()
            if len(fields := line.split()) == 4 and fields[0] == "__DATA"
            and fields[3] == "pointer"}


def code_addresses(image, reference):
    addresses = defaultdict(set)
    for row in read_manifests():
        if row.arch == image.arch:
            addresses[row.symbol].add(row.address)
    for key, values in reference.targets.items():
        if isinstance(key, tuple) and key[0] in ("thumb", "arm"):
            addresses[key[1]].update(values)
    return addresses


def method_name(obj, symbols, relocation, raw):
    # Each table entry must have a four-byte, absolute ARM_RELOC_VANILLA.
    # An external symbol has no in-object address. A local one is relative
    # to __text and may already carry the Thumb bit.
    if relocation >> 24 == 0x0c and raw == 0:
        return symbols.names[relocation & 0xffffff]
    if relocation >> 24 != 0x04 or relocation & 0xffffff != obj.text.index:
        raise ValueError("expected a function-pointer relocation")
    names = [name for name in symbols.defined.get(raw & ~1, [])
             if name in obj.symbols and obj.symbols[name].section == obj.text.index
             and obj.symbols[name].description & 8]
    if len(names) != 1:
        raise ValueError(f"ambiguous local Thumb method at {raw:#x}: {names}")
    return names[0]


def link_table(name, count, obj, symbols, image, reference, addresses, rebases):
    start = reference.unique(name)
    original = next((s for s in image.sections if s.addr <= start < s.addr + s.size), None)
    if original is None or original.segment != "__DATA" or original.name not in ("__const", "__data"):
        raise ValueError(f"{name} lies outside the native table sections")
    symbol = obj.symbols[name]
    section = obj.sections[symbol.section - 1]
    if (section.segment, section.name) != ("__DATA", "__const"):
        raise ValueError(f"{name} is missing its compiler-emitted pointer table")
    offset = symbol.addr - section.addr
    size = 8 + count * 4
    if offset + size > section.size or start + size > original.addr + original.size:
        raise ValueError(f"{name} crosses a section boundary")
    pos = section.offset + offset
    body = bytearray(obj.data[pos:pos + size])
    relocations = {}
    for index in range(section.nreloc):
        slot, spec = struct.unpack_from("<II", obj.data, section.reloff + 8 * index)
        if offset <= slot < offset + size:
            if slot - offset in relocations:
                raise ValueError(f"duplicate relocation in {name}")
            relocations[slot - offset] = spec
    slots = set(range(8, size, 4))
    if body[:8] != bytes(8) or relocations.keys() != slots:
        raise ValueError(f"{name} has unexpected offset-to-top, RTTI or method relocations")
    if {p - start for p in rebases if start <= p < start + size} != slots:
        raise ValueError(f"{name} slots disagree with the original dyld rebase table")
    for slot, spec in relocations.items():
        raw, = struct.unpack_from("<I", body, slot)
        method = method_name(obj, symbols, spec, raw)
        candidates = addresses.get(method, set())
        if len(candidates) != 1:
            raise ValueError(f"{name} has no unique code address for {method}")
        address, = candidates
        if image.starts.get(address) is not True:
            raise ValueError(f"{name} method {method} is not an original Thumb function start")
        struct.pack_into("<I", body, slot, address | 1)
    first = reference.file_offset(start)
    if body != image.data[first:first + size]:
        raise ValueError(f"{image.arch} linked virtual table {name} differs from the reference")
    return first, bytes(body)


def linked_vtables(image, tmp):
    reference = reference_layout(image.data)
    rebases = rebased_pointers(image, tmp)
    addresses = code_addresses(image, reference)
    clang = find_tool("clang")
    ranges = []
    for filename, tables in TABLES.items():
        path = tmp / f"{image.arch}-{filename}.vtables.o"
        subprocess.run([clang, "-target", f"{image.arch}-apple-ios7.0", "-mthumb",
                        "-ffreestanding", "-isysroot", "/", "-std=c99", "-O0", "-c",
                        ROOT / "src" / filename, "-o", path], check=True)
        obj = Image(path.read_bytes())
        if obj.filetype != 1 or obj.arch != image.arch:
            raise ValueError(f"wrong Mach-O object for {filename}")
        symbols = Layout(obj.data)
        for name, count in tables.items():
            ranges.append(link_table(name, count, obj, symbols, image, reference,
                                     addresses, rebases))
    return ranges
