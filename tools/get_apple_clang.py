#!/usr/bin/env python3
"""Build the ARM compiler from Apple's public clang-500.2.76 release."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
from urllib.request import urlopen

TAG = "clang-500.2.76"
URL = f"https://codeload.github.com/apple-oss-distributions/clang/tar.gz/refs/tags/{TAG}"
SHA256 = "92a0c7411e52cc81e362d9120a51d94036ad45114d1662dc3a8caecc0ce97a4c"
DEST = Path(__file__).resolve().parents[1] / ".toolchains/apple500/bin/clang"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="use a previously downloaded source release")
    parser.add_argument("-j", "--jobs", type=int, default=min(10, os.cpu_count() or 1))
    args = parser.parse_args()
    resources = DEST.parents[1] / "lib/clang/3.3/include"
    if DEST.is_file() and (resources / "stdarg.h").is_file():
        print(DEST)
        return
    if not shutil.which("cmake"):
        parser.error("CMake is required to build the Apple compiler")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="build-", dir=DEST.parent) as work:
        work = Path(work)
        archive = args.archive
        if archive is None:
            archive = work / "release.tar.gz"
            print(f"Downloading {TAG} from Apple’s source repository", flush=True)
            with urlopen(URL, timeout=120) as response, archive.open("wb") as output:
                shutil.copyfileobj(response, output)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
            parser.error(f"SHA-256 mismatch for {TAG}")
        with tarfile.open(archive, "r:gz") as package:
            # The archive checked above is pinned byte-for-byte. Older Python
            # versions bundled with Xcode do not support the filter argument.
            package.extractall(work)
        src = work / f"clang-{TAG}/src"
        # The release's build scripts are Python 2. The Xcode Python includes
        # lib2to3 and can run the converted scripts during CMake configuration.
        py = subprocess.check_output(["xcrun", "--find", "python3"], text=True).strip()
        subprocess.run([py, "-m", "lib2to3", "-w", "-n", str(src / "utils/llvm-build")],
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
        # This public release omits the clang tests referenced unconditionally
        # by CMake and has stale member names in an ASTVector member template.
        tests = src / "tools/clang/test"
        tests.mkdir(exist_ok=True)
        (tests / "CMakeLists.txt").touch()
        header = src / "tools/clang/include/clang/AST/ASTVector.h"
        header.write_text(header.read_text().replace("this->EndX < this->CapacityX",
                                                     "this->End < this->Capacity"))
        build = work / "build"
        subprocess.run(["cmake", "-S", str(src), "-B", str(build),
                        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DCMAKE_BUILD_TYPE=Release",
                        "-DLLVM_TARGETS_TO_BUILD=ARM", "-DLLVM_INCLUDE_TESTS=OFF",
                        "-DLLVM_INCLUDE_EXAMPLES=OFF", "-DLLVM_ENABLE_THREADS=OFF",
                        "-DLLVM_ENABLE_ASSERTIONS=OFF", "-DCMAKE_CXX_STANDARD=11",
                        "-DCMAKE_CXX_FLAGS=-w -D_LIBCPP_ENABLE_CXX17_REMOVED_UNEXPECTED_FUNCTIONS "
                        "-D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR", f"-DPYTHON_EXECUTABLE={py}"],
                       check=True)
        subprocess.run(["cmake", "--build", str(build), "--target", "clang", "--parallel",
                        str(max(1, args.jobs))], check=True)
        shutil.copytree(build / "lib/clang/3.3/include", resources, dirs_exist_ok=True)
        candidate = work / "clang"
        shutil.copy2(build / "bin/clang", candidate)
        candidate.replace(DEST)
    print(DEST)


if __name__ == "__main__":
    main()
