#!/usr/bin/env python3
"""Fetch the original Google Mobile Ads 6.8.0 archive for optional historical comparisons."""
import argparse
from pathlib import Path
import shutil
import tempfile
from urllib.request import urlopen

from get_llvm33 import sha256

URL = ("https://raw.githubusercontent.com/floatinghotpot/cordova-plugin-admob/"
       "adb32b97af2c2bd17b44165d45140b6eb8738297/src/ios/libGoogleAdMobAds.a")
DIGEST = "df318f69da0b05f88182d8eb9841023ecec4292903d60fb807ea51d2c1ddd258"
DEST = Path(__file__).resolve().parents[1] / ".toolchains/admob680/libGoogleAdMobAds.a"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", type=Path, help="local copy of the 6.8.0 library")
    args = parser.parse_args()
    if not DEST.is_file() or sha256(DEST) != DIGEST:
        DEST.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=DEST.parent) as temp:
            candidate = Path(temp) / DEST.name
            if args.library:
                shutil.copyfile(args.library, candidate)
            else:
                with urlopen(URL, timeout=120) as src, candidate.open("wb") as dst:
                    shutil.copyfileobj(src, dst)
            if sha256(candidate) != DIGEST:
                parser.error("unexpected AdMob 6.8.0 static library digest")
            candidate.replace(DEST)
    print(DEST)


if __name__ == "__main__":
    main()
