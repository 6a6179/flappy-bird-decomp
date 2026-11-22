#!/usr/bin/env python3
"""Regenerate the C-like Ghidra listing for Flappy Bird 1.2 on macOS."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def apple_tool(name, *args):
    return subprocess.check_output(["xcrun", name, *args], text=True)


def method_names(binary):
    """Read implemented methods, skipping protocol declarations and classrefs."""
    methods = {}
    section = owner = selector = category = sign = ""
    for line in apple_tool("otool", "-ov", binary).splitlines():
        if line.startswith("Contents of "):
            section = line.split(",")[-1].split(")")[0]
        if section == "__objc_classlist":
            if re.fullmatch(r"[a-fA-F0-9]+ 0x[a-fA-F0-9]+", line):
                sign = "-"
            elif line == "Meta Class":
                sign = "+"
            elif line.startswith("        name           "):
                owner = line.split()[-1]
            elif line.startswith("            name    "):
                selector = line.split()[-1]
            elif line.startswith("            imp     "):
                methods[int(line.split()[1], 16)] = f"{sign}[{owner} {selector}]"
        elif section == "__objc_catlist":
            if line.startswith("    name      "):
                category = line.split()[-1]
            elif line.startswith("    cls       "):
                owner = line.split()[-1].split("$_")[-1]
            elif line.startswith("    instanceMethods "):
                sign = "-"
            elif line.startswith("    classMethods "):
                sign = "+"
            elif line.startswith("        name    "):
                selector = line.split()[-1]
            elif line.startswith("        imp     "):
                methods[int(line.split()[1], 16)] = f"{sign}[{owner}({category}) {selector}]"
    return methods


def write_seeds(binary, path):
    headers = apple_tool("llvm-objdump", "--macho", "--section-headers", binary)
    _, size, base = next(line.split()[1:4] for line in headers.splitlines()
                         if re.match(r"\s*\d+ __text ", line))
    text_end = int(base, 16) + int(size, 16)
    lines = apple_tool("llvm-objdump", "--macho", "--function-starts", binary).splitlines()
    starts = [int(line, 16) for line in lines if re.fullmatch(r"[a-fA-F0-9]+", line)]
    names = method_names(binary)
    if not starts or sorted(starts) != starts or starts[0] & ~1 != int(base, 16):
        raise ValueError("Unexpected __text or LC_FUNCTION_STARTS layout")
    missing = names.keys() - set(starts)
    if missing:
        raise ValueError(f"Unlisted Objective-C implementations: {sorted(missing)}")
    with path.open("w") as seeds:
        for raw, following in zip(starts, starts[1:] + [text_end]):
            address, end = raw & ~1, following & ~1
            if not address < end <= text_end:
                raise ValueError("Invalid function interval")
            print(f"{address:x}", f"{end:x}", raw & 1, names.get(raw, ""), sep="\t", file=seeds)
    return len(starts)


def recover(archive, arch, headless, outdir):
    with tempfile.TemporaryDirectory(prefix=f"flap-{arch}-") as scratch:
        scratch = Path(scratch)
        universal = scratch / "flap"
        with archive.open("Payload/Flap.app/flap") as member, universal.open("wb") as output:
            shutil.copyfileobj(member, output)
        binary = scratch / arch
        apple_tool("lipo", universal, "-thin", arch, "-output", binary)
        seeds = scratch / "seeds.tsv"
        count = write_seeds(binary, seeds)
        output = scratch / "output"
        output.mkdir()
        subprocess.run([
            headless, scratch, "flap", "-import", binary, "-max-cpu", "3",
            "-processor", "ARM:LE:32:v7", "-cspec", "apcs",
            "-scriptPath", ROOT / "tools/decompiler", "-preScript",
            "RecoverFunctions.java", "seed", seeds, "-postScript",
            "RecoverFunctions.java", "export", seeds, output, "-deleteProject"
        ], check=True)
        if not (output / "index.tsv").is_file():
            raise RuntimeError(f"Ghidra produced no index for {arch}. See the headless log above.")
        index = (output / "index.tsv").read_text().splitlines()
        if len(index) != count + 1:
            raise RuntimeError(f"Expected {count} indexed functions, found {len(index) - 1}")
        target = outdir / arch
        target.mkdir(parents=True, exist_ok=True)
        for file in sorted(output.iterdir()):
            shutil.copyfile(file, target / file.name)
        emitted = sum(line.split("\t")[-1] in {"emitted", "emitted with warning"} for line in index[1:])
        print(f"{arch}: exported {emitted}/{count} functions to {target}", flush=True)
        if emitted != count:
            raise RuntimeError(f"{count - emitted} functions lack pseudocode; see {target / 'index.tsv'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, default=ROOT / "Flappy Bird v1.2.ipa")
    parser.add_argument("--ghidra", type=Path, default=os.getenv("GHIDRA_HOME"),
                        help="Ghidra distribution directory (or set GHIDRA_HOME)")
    parser.add_argument("--arch", choices=["armv7", "armv7s"], action="append")
    parser.add_argument("--out", type=Path, default=ROOT / "recovered")
    args = parser.parse_args()
    if not args.ghidra:
        parser.error("Set --ghidra or GHIDRA_HOME to the Ghidra distribution")
    headless = args.ghidra.resolve() / "support/analyzeHeadless"
    with zipfile.ZipFile(args.ipa) as archive:
        for arch in args.arch or ["armv7", "armv7s"]:
            recover(archive, arch, headless, args.out)


if __name__ == "__main__":
    main()
