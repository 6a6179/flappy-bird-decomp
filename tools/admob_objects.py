#!/usr/bin/env python3
"""Relocate complete functions from the pinned Google Mobile Ads 6.8.0 archive."""

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import struct
import subprocess
import tempfile

from decompile import method_names
from get_admob680 import DEST, DIGEST
from get_llvm33 import sha256
from linkmatch import Reference, object_layout, relocate_function
from verify import ROOT, original_images, read_manifests


def defined_symbols(member):
    symoff, count, _ = struct.unpack_from("<III", member.data, member.commands[2] + 8)
    for index in range(count):
        _, kind, section, description, address = struct.unpack_from(
            "<IBBHI", member.data, symoff + index * 12)
        if (kind & 0xee) == 0x0e:  # N_SECT, excluding debugging symbols
            yield member.names[index], kind, section, description, address


def member_functions(member):
    """Get function slots, instruction states and names from this relocatable object."""
    text = member.by_name.get("__text")
    if not text or not text.size:
        return {}
    symbols = defaultdict(list)
    text_index = member.sections.index(text) + 1
    for name, _, section, description, address in defined_symbols(member):
        if section == text_index and name.startswith(("+[", "-[", "_")):
            symbols[address].append((name, bool(description & 8)))

    # The relocatable has an unnamed segment at zero. The first function also
    # starts at zero and so cannot be represented by a nonzero ULEB delta.
    if text.addr != 0 or 0x26 not in member.commands:
        raise ValueError("unexpected SDK object text layout")
    offset, size = struct.unpack_from("<II", member.data, member.commands[0x26] + 8)
    starts = [0]
    address = delta = shift = 0
    for byte in member.data[offset:offset + size]:
        delta |= (byte & 127) << shift
        if byte & 128:
            shift += 7
            continue
        if delta == 0:
            break
        address += delta
        start = address & ~1
        if address == 1 and starts == [0]:  # first Thumb function at offset zero
            shift = delta = 0
            continue
        if not starts[-1] < start < text.size:
            raise ValueError("invalid SDK object function-start table")
        starts.append(start)
        shift = delta = 0
    return {start: (end - start, symbols[start])
            for start, end in zip(starts, starts[1:] + [text.size])}


def placements(image, slots, methods):
    """Place named methods directly and other functions only in an intact section."""
    known = {}
    for start, (_, symbols) in slots.items():
        destinations = {methods[name] for name, thumb in symbols if name in methods
                        and image.starts.get(methods[name]) == thumb}
        if len(destinations) == 1:
            known[start] = destinations.pop()
        elif destinations:
            return {}
    slides = {dst - start for start, dst in known.items()}
    if len(known) >= 2 and len(slides) == 1:
        slide = slides.pop()
        # Require the full section's boundary sequence to survive the final link,
        # including the end of the final function. An inserted or removed function
        # rules out placement of any unnamed-by-Objective-C companion.
        if all(image.ends.get(start + slide) == start + slide + size
               for start, (size, _) in slots.items()):
            for start, (_, symbols) in slots.items():
                dst = start + slide
                if symbols and all(image.starts[dst] == thumb for _, thumb in symbols):
                    known[start] = dst
    return known


def string_initializers(member, ref, definitions):
    """Read externally named constant pointers with a local relocation to a CFString."""
    const = member.by_name.get("__const")
    strings = member.by_name.get("__cfstring")
    if not const or not strings or const.segment != "__DATA" or strings.segment != "__DATA":
        return {}
    section_number = member.sections.index(const) + 1
    names = {address: name for name, kind, section, _, address in definitions
             if kind & 1 and section == section_number and member.defined[address] == [name]}
    # Non-scattered, non-PC-relative, four-byte ARM_RELOC_VANILLA to __cfstring.
    local_pointer = (4 << 24) | (member.sections.index(strings) + 1)
    initializers = {}
    for address, flags, desc, _ in member.relocations[const.name]:
        if flags >> 31 or desc != local_pointer or address not in names or address % 4:
            continue
        if not const.addr <= address <= const.addr + const.size - 4:
            continue
        target = member.read(address)
        if not (strings.addr <= target <= strings.addr + strings.size - 16
                and (target - strings.addr) % 16 == 0):
            continue
        linked = ref.targets.get(("__cfstring", member.cfstring(target)), ())
        if len(linked) == 1:
            initializers[address] = names[address], next(iter(linked))
    return initializers


def place_initializers(initializers, const_data, const_base):
    """Place an adjacent run of constant definitions by its entire initializer sequence."""
    for start in initializers:
        if start - 4 in initializers:
            continue
        run = []
        pos = start
        while pos in initializers:
            run.append(initializers[pos])
            pos += 4
        if len({value for _, value in run}) < 2:
            continue
        pattern = b"".join(struct.pack("<I", value) for _, value in run)
        offset = const_data.find(pattern)
        if offset < 0 or offset % 4 or const_data.find(pattern, offset + 1) >= 0:
            continue
        for index, (name, _) in enumerate(run):
            yield name, const_base + offset + 4 * index


def add_constant_imports(ref, candidates, definition_counts):
    """Add unambiguous nonlazy import slots only to the archive's reference layout."""
    name_counts = Counter(name for name, _ in candidates)
    address_counts = Counter(address for _, address in candidates)
    slots = defaultdict(list)
    for slot in ref.pointers("__nl_symbol_ptr"):
        slots[ref.read(slot)].append(slot)
    named_slots = set()
    for key, targets in ref.targets.items():
        if isinstance(key, tuple) and key[0] == "__nl_symbol_ptr":
            named_slots.update(targets)
    for name, address in candidates:
        if definition_counts[name] != 1 or name_counts[name] != 1 or address_counts[address] != 1:
            continue
        if len(slots[address]) != 1 or (name in ref.targets and ref.targets[name] != {address}):
            continue
        slot = slots[address][0]
        key = ("__nl_symbol_ptr", name)
        if key not in ref.targets and slot not in named_slots:
            ref.targets[key].add(slot)


def linked_sdk_objects(image, compiled):
    """Return additional {original VM address: relocated SDK bytes} for one slice."""
    if not DEST.exists():
        return {}
    if sha256(DEST) != DIGEST:
        raise ValueError("unexpected AdMob archive digest")
    # These data definitions belong to the pinned archive. Keep their lookup
    # separate from reference_layout(), the cache used by source verification.
    ref = Reference(image.data)
    const = next(s for s in ref.sections if (s.segment, s.name) == ("__DATA", "__const"))
    const_data = image.data[const.offset:const.offset + const.size]
    constants = []
    definition_counts = Counter()
    proposed = defaultdict(list)
    with tempfile.TemporaryDirectory(prefix="flap-admob-") as directory:
        scratch = Path(directory)
        binary = scratch / "Flap"
        binary.write_bytes(image.data)
        # otool obtains each class/category, selector and IMP from ObjC metadata.
        named = {address & ~1: name for address, name in method_names(binary).items()}
        counts = Counter(named.values())
        methods = {name: addr for addr, name in named.items() if counts[name] == 1}
        archive = scratch / "sdk.a"
        subprocess.run(["xcrun", "lipo", DEST, "-thin", image.arch, "-output", archive], check=True)
        subprocess.run(["ar", "-x", archive], cwd=scratch, check=True)
        for member_path in sorted(scratch.glob("*.o")):
            member = object_layout(member_path.read_bytes())
            definitions = list(defined_symbols(member))
            definition_counts.update(name for name, kind, _, _, _ in definitions if kind & 1)
            constants.extend(place_initializers(string_initializers(member, ref, definitions),
                                                const_data, const.addr))
            slots = member_functions(member)
            for start, dst in placements(image, slots, methods).items():
                size, _ = slots[start]
                if dst not in compiled and image.ends[dst] - dst == size:
                    proposed[dst].append((member, start, size))

    add_constant_imports(ref, constants, definition_counts)
    result = {}
    for dst, candidates in proposed.items():
        if len(candidates) != 1:
            continue
        member, start, size = candidates[0]
        try:
            body = relocate_function(member, ref, start, dst, size)
        except ValueError as error:
            # Malformed input or an invalid relocation encoding is an error.
            # Missing layout evidence and unsupported relocation kinds are expected.
            if not str(error).startswith(("no symbol mapping", "expected one original link target",
                                          "unmapped ", "unsupported ")):
                raise
            # For example, a stripped static variable or jump-table target can
            # have no independent layout anchor. Assembly still owns its slot.
            continue
        if body == image.text_bytes(dst, size):
            result[dst] = body
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, default=ROOT / "Flappy Bird v1.2.ipa")
    args = parser.parse_args()
    if not DEST.exists():
        parser.error("install the pinned archive with tools/get_admob680.py")
    rows = list(read_manifests())
    for arch, image in original_images(args.ipa).items():
        result = linked_sdk_objects(image, {row.address for row in rows if row.arch == arch})
        print(f"{arch}: {len(result)} additional SDK functions, {sum(map(len, result.values()))} bytes")


if __name__ == "__main__":
    main()
