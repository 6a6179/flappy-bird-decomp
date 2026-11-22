#!/usr/bin/env python3
"""Extract shipped Apple clang-600.0.57 from the Mavericks CLT package.

This compiler contains Apple's Cortex-A9 erratum 754319 workaround.
Apple Silicon hosts need Rosetta to run the x86_64 compiler.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.request import urlopen

from get_llvm33 import sha256

URL = ("https://swcdn.apple.com/content/downloads/52/38/041-84772-A_3Q6IYQ9NMX/"
       "qoztgaj2s53szwqkvg68ntwpa675qaef2q/CLTools_Executables_OSX109.pkg")
PKG_SHA256 = "a12fdfe0b9d518cd6d781d45ce5f6b9c938b5039dda90de97fe45b69c5b20f04"
CLANG_SHA256 = "7fc2e722d60c80cb12b6a261e901c887513b8697794e3773daf8d0f72f4dd18c"
DEST = Path(__file__).resolve().parents[1] / ".toolchains/apple600"
HEADERS = Path("lib/clang/6.0/include")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="use a previously downloaded Apple .pkg")
    archive = parser.parse_args().archive
    clang = DEST / "bin/clang"
    if clang.is_file() and sha256(clang) == CLANG_SHA256 and (DEST / HEADERS / "stdarg.h").is_file():
        print(clang)
        return
    clang.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=DEST) as temp:
        scratch = Path(temp)
        if archive is None:
            archive = scratch / "CLTools.pkg"
            print(f"Downloading {URL}", flush=True)
            with urlopen(URL, timeout=120) as response, archive.open("wb") as out:
                shutil.copyfileobj(response, out)
        if sha256(archive) != PKG_SHA256:
            parser.error("Mavericks CLT package SHA-256 mismatch")
        subprocess.run(["/usr/bin/xar", "-xf", archive.resolve(), "Payload"], cwd=scratch, check=True)
        usr = Path("Library/Developer/CommandLineTools/usr")
        subprocess.run(["/usr/bin/tar", "-xf", "Payload", "./" + str(usr / "bin/clang"),
                        "./" + str(usr / HEADERS)], cwd=scratch, check=True)
        candidate = scratch / usr / "bin/clang"
        if sha256(candidate) != CLANG_SHA256:
            parser.error("Extracted compiler SHA-256 mismatch")
        shutil.copytree(scratch / usr / HEADERS, DEST / HEADERS, dirs_exist_ok=True)
        candidate.replace(clang)
    print(clang)


if __name__ == "__main__":
    main()
