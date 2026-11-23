#!/usr/bin/env python3
"""Build an ARM compiler from Apple's public Clang sources."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
from urllib.request import urlopen

RELEASES = {
    "421": ("clang-421.11.65", "3.1", "6ac902c9b8def5c5fde9140f3b8cd47a2eb75b95e203f120088b757a0c34d284"),
    "500": ("clang-500.2.76", "3.3", "92a0c7411e52cc81e362d9120a51d94036ad45114d1662dc3a8caecc0ce97a4c"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", choices=RELEASES, default="500")
    parser.add_argument("--archive", type=Path, help="use a previously downloaded source release")
    parser.add_argument("-j", "--jobs", type=int, default=min(10, os.cpu_count() or 1))
    args = parser.parse_args()
    tag, version, digest = RELEASES[args.release]
    dest = Path(__file__).resolve().parents[1] / f".toolchains/apple{args.release}/bin/clang"
    include = Path("lib/clang") / version / "include"
    resources = dest.parents[1] / include
    if dest.is_file() and (resources / "stdarg.h").is_file():
        print(dest)
        return
    if not shutil.which("cmake"):
        parser.error("CMake is required to build the Apple compiler")
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="build-", dir=dest.parent) as work:
        work = Path(work)
        archive = args.archive
        if archive is None:
            archive = work / "release.tar.gz"
            print(f"Downloading {tag} from Apple’s source repository", flush=True)
            url = f"https://codeload.github.com/apple-oss-distributions/clang/tar.gz/refs/tags/{tag}"
            with urlopen(url, timeout=120) as response, archive.open("wb") as output:
                shutil.copyfileobj(response, output)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
            parser.error(f"SHA-256 mismatch for {tag}")
        with tarfile.open(archive, "r:gz") as package:
            # The archive checked above is pinned byte-for-byte. Older Python
            # versions bundled with Xcode do not support the filter argument.
            package.extractall(work)
        src = work / f"clang-{tag}/src"
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
        if args.release == "421":
            # This release bundles an incomplete libc++ project. Only the host
            # library is needed for the compiler. Its CFG iterators also need
            # their actual pointer-valued dereference type for current libc++.
            (src / "projects/libcxx").rename(work / "libcxx")
            cfg = src / "include/llvm/Support/CFG.h"
            pointer = "typedef typename super::pointer pointer;"
            cfg.write_text(cfg.read_text().replace(
                pointer, pointer + "\n  typedef pointer value_type;\n  typedef pointer reference;"))
            vtable = src / "tools/clang/lib/AST/VTableBuilder.cpp"
            vtable.write_text(vtable.read_text().replace('"PRIu64"', '" PRIu64 "'))
            arc = src / "lib/Transforms/Scalar/ObjCARC.cpp"
            arc.write_text(arc.read_text().replace("insert(next(", "insert(llvm::next("))
            debug = src / "tools/clang/lib/CodeGen/CGDebugInfo.cpp"
            source = debug.read_text()
            for value in ("T", "TC"):
                source = source.replace(f"Ty.getAsOpaquePtr(), {value}));",
                                        f"Ty.getAsOpaquePtr(), llvm::WeakVH({value})));")
            debug.write_text(source)
            # AV may be null if jump threading never initialized an SSA update.
            # Forming a reference before deleting it loses the null check.
            updater = src / "lib/Transforms/Utils/SSAUpdater.cpp"
            updater.write_text(updater.read_text().replace(
                "delete &getAvailableVals(AV);", "delete static_cast<AvailableValsTy *>(AV);"))
            # Supply the tag normally recorded by Apple's release makefiles.
            with (src / "tools/clang/lib/Basic/CMakeLists.txt").open("a") as cmake:
                cmake.write(f'\nset_source_files_properties(Version.cpp PROPERTIES '
                            f'COMPILE_DEFINITIONS "CLANG_REPOSITORY_STRING=\\"{tag}\\"")\n')
        threads = "ON" if args.release == "421" else "OFF"
        build = work / "build"
        subprocess.run(["cmake", "-S", str(src), "-B", str(build),
                        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DCMAKE_BUILD_TYPE=Release",
                        "-DLLVM_TARGETS_TO_BUILD=ARM", "-DLLVM_INCLUDE_TESTS=OFF",
                        "-DLLVM_INCLUDE_EXAMPLES=OFF", f"-DLLVM_ENABLE_THREADS={threads}",
                        "-DLLVM_ENABLE_ASSERTIONS=OFF", "-DCMAKE_CXX_STANDARD=11",
                        "-DCMAKE_CXX_FLAGS=-w -D_LIBCPP_ENABLE_CXX17_REMOVED_UNEXPECTED_FUNCTIONS "
                        "-D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR", f"-DPYTHON_EXECUTABLE={py}"],
                       check=True)
        targets = ["clang", "clang-headers"] if args.release == "421" else ["clang"]
        subprocess.run(["cmake", "--build", str(build), "--target", *targets, "--parallel",
                        str(max(1, args.jobs))], check=True)
        shutil.copytree(build / include, resources, dirs_exist_ok=True)
        candidate = work / "clang"
        shutil.copy2(build / "bin/clang", candidate)
        candidate.replace(dest)
    print(dest)


if __name__ == "__main__":
    main()
