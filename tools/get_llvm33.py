#!/usr/bin/env python3
"""Install the single compiler executable used for the LLVM 3.3 matches."""
import argparse
import hashlib
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
from urllib.request import urlopen

PACKAGE = "clang+llvm-3.3-x86_64-apple-darwin12"
URL = f"https://releases.llvm.org/3.3/{PACKAGE}.tar.gz"
ARCHIVE_SHA256 = "9c21b9fdcf318158a721eee69d10a00421ddb02dda6e2c0f6ec7ce4f59ff51eb"
CLANG_SHA256 = "586c125a4c937af461c0bce52dab9613986b480e3f09e6b8dccff64e0b637aa6"
DEST = Path(__file__).resolve().parents[1] / ".toolchains/llvm33/bin/clang"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="use a previously downloaded release archive")
    archive = parser.parse_args().archive
    if DEST.is_file() and sha256(DEST) == CLANG_SHA256:
        print(DEST)
        return
    DEST.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=DEST.parent) as temp:
        if archive is None:
            archive = Path(temp) / "release.tar.gz"
            print(f"Downloading {URL}", flush=True)
            with urlopen(URL, timeout=60) as response, archive.open("wb") as stream:
                shutil.copyfileobj(response, stream)
        if sha256(archive) != ARCHIVE_SHA256:
            sys.exit("LLVM archive SHA-256 mismatch")
        candidate = Path(temp) / "clang"
        with tarfile.open(archive, "r:gz") as package:
            member = package.getmember(PACKAGE + "/bin/clang")
            if not member.isfile():
                sys.exit("Expected a regular compiler executable")
            with package.extractfile(member) as source, candidate.open("wb") as target:
                shutil.copyfileobj(source, target)
        if sha256(candidate) != CLANG_SHA256:
            sys.exit("Compiler SHA-256 mismatch")
        candidate.chmod(0o755)
        candidate.replace(DEST)
    print(DEST)


if __name__ == "__main__":
    main()
