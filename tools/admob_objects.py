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
from linkmatch import link_function, object_layout
from verify import ROOT, original_images, read_manifests


def member_functions(member):
    """Get function slots, instruction states and names from this relocatable object."""
    text = member.by_name.get("__text")
    if not text or not text.size:
        return {}
    symbols = defaultdict(list)
    symoff, count, _ = struct.unpack_from("<III", member.data, member.commands[2] + 8)
    text_index = member.sections.index(text) + 1
    for index in range(count):
        _, kind, section, description, address = struct.unpack_from(
            "<IBBHI", member.data, symoff + index * 12)
        if section == text_index and (kind & 0xee) == 0x0e:
            name = member.names[index]
            if name.startswith(("+[", "-[", "_")):
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


def linked_sdk_objects(image, compiled):
    """Return additional {original VM address: relocated SDK bytes} for one slice."""
    if not DEST.exists():
        return {}
    if sha256(DEST) != DIGEST:
        raise ValueError("unexpected AdMob archive digest")
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
            slots = member_functions(member)
            for start, dst in placements(image, slots, methods).items():
                size, _ = slots[start]
                if dst not in compiled and image.ends[dst] - dst == size:
                    proposed[dst].append((member.data, start, size))

    result = {}
    for dst, candidates in proposed.items():
        if len(candidates) != 1:
            continue
        data, start, size = candidates[0]
        try:
            body = link_function(data, image.data, start, dst, size)
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
