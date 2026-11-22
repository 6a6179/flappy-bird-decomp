#!/usr/bin/env python3
"""Install iOS 7 headers for matching, or the complete SDK for linking an app."""
import argparse
from pathlib import Path
import shutil
import tempfile
from urllib.request import urlopen
import zipfile

from get_llvm33 import sha256

TOOLCHAINS = Path(__file__).resolve().parents[1] / ".toolchains"
DEST = TOOLCHAINS / "iphoneos7"
SDK_NAME = "iPhoneOS7.0.sdk"
MIRROR = f"https://raw.githubusercontent.com/qianjigui/iOS-sdks/189a487850e3351cf624b5cef9c8317138c89b05/{SDK_NAME}"
SHA256 = "e4a7c3924832201de1b499eb8075f19618b7cb864a066ab5a555f805e583b7a0"
CHECK_HEADER = Path("System/Library/Frameworks/Foundation.framework/Headers/Foundation.h")
CPP_INCLUDE = Path("usr/include/c++/4.2.1")
HEADER_CHECKS = (CHECK_HEADER, CPP_INCLUDE / "iostream", CPP_INCLUDE / "bits/basic_string.tcc")
SDK_CHECKS = HEADER_CHECKS + (Path("usr/lib/libSystem.B.dylib"), Path("SDKSettings.plist"))


def is_public_header(path):
    parts = path.parts
    if path.is_absolute() or ".." in parts:
        return False
    if path.is_relative_to(CPP_INCLUDE):
        return True
    return path.suffix == ".h" and (
        parts[:2] == ("usr", "include")
        or (parts[:3] == ("System", "Library", "Frameworks")
            and len(parts) >= 6 and parts[4] == "Headers"))


def fetch_archive(path):
    with path.open("wb") as out:
        for part in range(1, 6):
            print(f"Downloading {SDK_NAME} part {part}/5", flush=True)
            with urlopen(f"{MIRROR}/{SDK_NAME}.zip.{part:03}", timeout=120) as response:
                shutil.copyfileobj(response, out)


def extract_archive(archive, stage, full):
    if sha256(archive) != SHA256:
        raise ValueError("iOS 7 SDK archive SHA-256 mismatch")
    with zipfile.ZipFile(archive) as sdk:
        for entry in sdk.infolist():
            path = Path(entry.filename)
            if path.parts[:1] != (SDK_NAME,) or ".." in path.parts or entry.is_dir():
                continue
            rel = path.relative_to(SDK_NAME)
            if not full and not is_public_header(rel):
                continue
            dst = stage / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                link = Path(sdk.read(entry).decode())
                resolved = (dst.parent / link).resolve()
                if link.is_absolute() or not resolved.is_relative_to(stage):
                    raise ValueError(f"unexpected SDK symlink {entry.filename}")
                if full:
                    dst.symlink_to(link)
                else:
                    dst.write_bytes(sdk.read(str(Path(SDK_NAME) / resolved.relative_to(stage))))
            else:
                with sdk.open(entry) as src, dst.open("wb") as output:
                    shutil.copyfileobj(src, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--sdk", type=Path, help="installed iPhoneOS7.0.sdk from Xcode 5")
    group.add_argument("--archive", type=Path, help="the complete pinned SDK zip")
    parser.add_argument("--full", action="store_true", help="include the framework and library binaries")
    args = parser.parse_args()
    dest = TOOLCHAINS / SDK_NAME if args.full else DEST
    checks = SDK_CHECKS if args.full else HEADER_CHECKS
    if all((dest / path).is_file() for path in checks):
        print(dest)
        return
    TOOLCHAINS.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ios7-", dir=TOOLCHAINS) as temp:
        stage = Path(temp) / "sdk"
        if args.sdk:
            if not all((args.sdk / path).is_file() for path in checks):
                parser.error("expected an installed iPhoneOS7.0.sdk")
            if args.full:
                shutil.copytree(args.sdk, stage, symlinks=True)
            else:
                for src in args.sdk.rglob("*"):
                    rel = src.relative_to(args.sdk)
                    if is_public_header(rel) and src.is_file():
                        dst = stage / rel
                        dst.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(src, dst)
        else:
            archive = args.archive or Path(temp) / "sdk.zip"
            if args.archive is None:
                fetch_archive(archive)
            extract_archive(archive, stage, args.full)
        if not all((stage / path).is_file() for path in checks):
            parser.error("SDK installation is incomplete")
        if dest.exists():
            shutil.copytree(stage, dest, dirs_exist_ok=True, symlinks=args.full)
        else:
            stage.rename(dest)
    print(dest)


if __name__ == "__main__":
    main()
