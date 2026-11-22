#!/usr/bin/env python3
"""Install the signed compiler and builtin headers from Xcode 5.0.2 (5A3005)."""
import argparse
from contextlib import contextmanager
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

from get_llvm33 import sha256


IMAGE = "https://archive.org/download/xcode_archives/Xcode_5.0.2.dmg"
DEST = Path(__file__).resolve().parents[1] / ".toolchains/apple502"
COMPILER = Path("bin/clang")
HEADERS = Path("lib/clang/5.0/include")
COMPILER_HASH = "0e1c1d15c8ca75378a5f408c5c34b65209e0e750fc8cf037d276d10889b6ddeb"
HEADERS_HASH = "35fffe0d2ce28397445d35fb36105afc3628ab64fc109dbfff3330dd7e2c38e8"


def header_digest(directory):
    digest = hashlib.sha256()
    for header in sorted(directory.rglob("*")):
        if header.is_file():
            digest.update(header.relative_to(directory).as_posix().encode() + b"\0")
            digest.update(bytes.fromhex(sha256(header)))
    return digest.hexdigest()


def verified(root):
    return ((root / COMPILER).is_file() and sha256(root / COMPILER) == COMPILER_HASH
            and header_digest(root / HEADERS) == HEADERS_HASH)


@contextmanager
def mounted_xcode(image, work):
    mount = work / "image"
    mount.mkdir()
    subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, image],
                   check=True)
    try:
        yield mount / "Xcode.app"
    finally:
        subprocess.run(["hdiutil", "detach", mount], check=True)


def install(xcode, stage):
    usr = xcode / "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr"
    (stage / COMPILER.parent).mkdir(parents=True)
    shutil.copyfile(usr / COMPILER, stage / COMPILER)
    shutil.copytree(usr / HEADERS, stage / HEADERS)
    if not verified(stage):
        raise ValueError("Xcode compiler or builtin header checksum mismatch")
    subprocess.run(["codesign", "--verify", stage / COMPILER], check=True)
    (stage / COMPILER).chmod(0o755)
    stage.rename(DEST)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--xcode", type=Path, help="path to an extracted Xcode 5.0.2 app")
    source.add_argument("--image", type=Path, help="local Xcode_5.0.2.dmg")
    args = parser.parse_args()
    if not verified(DEST):
        if DEST.exists():
            parser.error(f"existing installation at {DEST} has different contents")
        DEST.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=DEST.parent) as temp:
            work = Path(temp)
            if args.xcode:
                install(args.xcode, work / "compiler")
            else:
                with mounted_xcode(args.image or IMAGE, work) as xcode:
                    install(xcode, work / "compiler")
    print(DEST / COMPILER)


if __name__ == "__main__":
    main()
