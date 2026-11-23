#!/usr/bin/env python3
"""Reassemble a complete Flappy Bird code section offline at its original layout."""
import argparse
from bisect import bisect_right
import gzip
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile

from verify import Image, ROOT, find_tool

# These digests cover only __TEXT,__text, extracted from the two reference slices.
TEXT_SHA256 = {
    "armv7": "97cd8a91973ed66c9ac70aeb2dbcfc05bf92d6b08d9c44e6b2e16f7ab268a48d",
    "armv7s": "f4fd4b402b99e1de8218a4224b65865bb915350daf059bbd512da65267359a2b",
}


def compile_text(arch, source, scratch):
    obj = scratch / "code.o"
    subprocess.run([
        find_tool("clang"), "-target", arch + "-apple-ios7.0", "-Wno-incompatible-sysroot",
        "-c", source.resolve(), "-o", obj.resolve()
    ], check=True, cwd=scratch)
    image = Image(obj.read_bytes())
    if image.arch != arch or image.text.nreloc:
        raise ValueError(f"Unexpected architecture or outstanding __text relocations in {obj}")
    return image.text_bytes(image.text.addr, image.text.size)


def write_mixed_source(image, compiled, listing, source, payload):
    """Emit every original slot once, using C bodies first and assembly for the gaps."""
    starts = sorted(image.starts)
    if compiled.keys() - image.starts.keys():
        raise ValueError(f"{image.arch}: compiled entry outside LC_FUNCTION_STARTS")

    # The generated listings annotate each statement with its original VM
    # address. Only retained statements can introduce a branch or table label.
    fallback = {start: [] for start in starts}
    targets = set()
    for line in listing:
        if not line.startswith("    "):
            continue
        statement, marker, comment = line.strip().rpartition("  @ ")
        if not marker:
            raise ValueError(f"missing VM address on assembly statement: {line.rstrip()}")
        addr = int(comment[:8], 16)
        slot = bisect_right(starts, addr) - 1
        if slot < 0 or addr >= image.ends[starts[slot]]:
            raise ValueError(f"{image.arch}: assembly outside a function at {addr:#x}")
        start = starts[slot]
        if addr < start + len(compiled.get(start, b"")):
            continue
        fallback[start].append((addr, line))
        targets.update(int(label, 16) for label in re.findall(r"\bL([0-9a-f]{8})\b", statement))

    # Split .incbin at any interior targets referenced from a fallback function.
    # Those labels are derived from its operands, independent of the archived
    # assembly for the compiled body.
    interior = {start: [] for start in compiled}
    for addr in sorted(targets):
        slot = bisect_right(starts, addr) - 1
        if slot >= 0:
            start = starts[slot]
            if start < addr < start + len(compiled.get(start, b"")):
                interior[start].append(addr)

    source.write(".syntax unified\n.text\n")
    previous_mode = None
    for start in starts:
        thumb = image.starts[start]
        if thumb != previous_mode:
            source.write(".thumb\n" if thumb else ".arm\n")
            previous_mode = thumb
        source.write(f"L{start:08x}:\n")
        if start in compiled:
            body = compiled[start]
            end = start + len(body)
            if not body or end > image.ends[start]:
                raise ValueError(f"{image.arch}: invalid compiled extent at {start:#x}")
            pos = payload.tell()
            payload.write(body)
            segment = start
            for stop in [*interior[start], end]:
                if segment != start:
                    source.write(f"L{segment:08x}:\n")
                source.write(f'    .incbin "compiled.bin", {pos + segment - start}, {stop - segment}\n')
                segment = stop
        for addr, line in fallback[start]:
            if addr != start and addr in targets:
                source.write(f"L{addr:08x}:\n")
            source.write(line)


def complete_text(image, compiled):
    """Join every generated slot, including its padding, and check the section digest."""
    missing = image.starts.keys() - compiled.keys()
    extra = compiled.keys() - image.starts.keys()
    if missing or extra:
        raise ValueError(f"{image.arch}: incomplete __text layout, missing {sorted(map(hex, missing))}, "
                         f"unexpected {sorted(map(hex, extra))}")
    starts = sorted(compiled)
    if not starts or starts[0] != image.text.addr:
        raise ValueError(f"{image.arch}: missing start of __text")
    for address in starts:
        if len(compiled[address]) != image.ends[address] - address:
            raise ValueError(f"{image.arch}: incomplete generated slot at {address:#x}")
    data = b"".join(compiled[address] for address in starts)
    if len(data) != image.text.size or hashlib.sha256(data).hexdigest() != TEXT_SHA256[image.arch]:
        raise ValueError(f"{image.arch}: source-generated __text differs from the reference")
    return data


def assemble_mixed(image, compiled, scratch):
    """Build a partial reconstruction and use archived assembly for remaining ranges."""
    if (compiled.keys() == image.starts.keys() and
            all(len(body) == image.ends[start] - start for start, body in compiled.items())):
        return complete_text(image, compiled)
    source = scratch / "mixed.s"
    packed = ROOT / "assembly" / (image.arch + ".s.gz")
    with gzip.open(packed, "rt") as listing, source.open("w") as asm, (scratch / "compiled.bin").open("wb") as bodies:
        write_mixed_source(image, compiled, listing, asm, bodies)
    data = compile_text(image.arch, source, scratch)
    if len(data) != image.text.size or hashlib.sha256(data).hexdigest() != TEXT_SHA256[image.arch]:
        raise ValueError(f"{image.arch} mixed __text section differs from the reference")
    return data


def assemble(arch, output):
    """Write the standalone __text section to output, after checking its digest."""
    packed = ROOT / "assembly" / (arch + ".s.gz")
    with tempfile.TemporaryDirectory(prefix="flap-asm-") as temp:
        scratch = Path(temp)
        source = scratch / "code.s"
        source.write_bytes(gzip.decompress(packed.read_bytes()))
        data = compile_text(arch, source, scratch)
    if hashlib.sha256(data).hexdigest() != TEXT_SHA256[arch]:
        raise ValueError(f"Assembled {arch} code differs from the reference digest")
    Path(output).write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    build = commands.add_parser("assemble", help="assemble without the IPA")
    build.add_argument("--arch", choices=TEXT_SHA256, required=True)
    build.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assemble(args.arch, args.output)
    print(f"{args.arch} {TEXT_SHA256[args.arch]}  {args.output}")


if __name__ == "__main__":
    main()
