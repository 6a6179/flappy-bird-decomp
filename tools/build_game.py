#!/usr/bin/env python3
"""Compile and link an editable, unsigned Flappy Bird IPA for ARMv7 and ARMv7s.

Install the historical compiler and iPhoneOS SDK with make setup-editable.
Use --sdk to select an existing full SDK. The default assets/ directory contains
the bundle plist, artwork, atlas and sounds. --assets also accepts another
resource directory or the original IPA.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path, PurePosixPath
import plistlib
import subprocess
import sys
from tempfile import TemporaryDirectory
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    "app_delegate.m", "view.m", "engine_frame.c", "gameplay.c", "gameplay_init.c",
    "native.c", "renderer.c", "renderer_atlas.c", "scene.c", "scene_numbers.c",
    "scene_overlays.c",
)
ARCHES = ("armv7", "armv7s")
FRAMEWORKS = (
    "CoreTelephony", "Social", "GameKit", "SystemConfiguration", "MessageUI",
    "iAd", "AVFoundation", "OpenAL", "AudioToolbox", "QuartzCore", "UIKit",
    "OpenGLES", "Foundation", "CoreGraphics", "CoreFoundation",
)
BUNDLE_FILES = {"Info.plist", "ObjectAL-Info.plist", "PkgInfo", "LICENSE.ObjectAL.txt", "atlas.txt"}
REQUIRED_ASSETS = {"atlas.png", "atlas.txt", "sfx_die.caf", "sfx_hit.caf",
                   "sfx_point.aif", "sfx_swooshing.caf", "sfx_wing.caf"}
BUNDLE_PREFIX = "Payload/Flap.app/"


def build_slice(arch, work, sdk, clang):
    from editable_admob_sources import METHOD_OWNERS, sources as admob_sources
    from editable_objc import merge_objc_assembly

    base = [clang, "-target", f"{arch}-apple-ios6.0", "-mthumb", "-integrated-as",
            "-Os", "-isysroot", sdk]
    game_flags = ["-DNS_BLOCK_ASSERTIONS=1", "-fno-exceptions"]
    jobs = []
    sources = [ROOT / "src" / name for name in SOURCES]
    sources.extend(sorted((ROOT / "src/objectal").glob("*.m")))
    sources.extend(sorted((ROOT / "src/objectal").glob("*.c")))
    for source in sources:
        flags = ["-std=gnu99"]
        if source.suffix == ".m":
            flags.extend(["-fno-objc-arc", "-fno-objc-exceptions", "-fvisibility=hidden"])
        if source.name == "view.m":
            flags.append("-DFLAP_EDITABLE_VIEW")
        jobs.append((source, game_flags + flags, work / f"{arch}-{source.stem}.o"))
    for owner in ("view", "engine", "game"):
        flags = ["-std=c++98", "-nostdinc++", "-isystem", sdk / "usr/include/c++/4.2.1",
                 f"-DFLAP_STREAM_GUARD={owner}_streams"]
        jobs.append((ROOT / "src/stream_init.cpp", game_flags + flags, work / f"{arch}-{owner}-streams.o"))

    sdk_inputs = admob_sources(sdk)
    objc_inputs = {}
    for source, flags in sdk_inputs:
        if source.suffix == ".m":
            assembly = work / f"{arch}-{source.stem}.s"
            objc_inputs[source] = assembly
            jobs.append((source, flags, assembly))
        else:
            jobs.append((source, flags, work / f"{arch}-{source.stem}.o"))

    def compile_input(job):
        source, flags, output = job
        stage = "-S" if output.suffix == ".s" else "-c"
        subprocess.run([*base, *flags, stage, source, "-o", output], check=True)

    with ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 1)) as pool:
        list(pool.map(compile_input, jobs))

    runtime = objc_inputs.pop(ROOT / "src/editable_admob_runtime.m")
    merged = merge_objc_assembly(runtime, objc_inputs, METHOD_OWNERS)
    objc_object = merged.with_suffix(".o")
    subprocess.run([*base, "-x", "assembler", "-c", merged, "-o", objc_object], check=True)
    # The recovered runtime owns the full SDK protocols referenced by the game.
    objects = [objc_object, *(output for _, _, output in jobs if output.suffix == ".o")]

    thin = work / f"flap-{arch}"
    command = ["xcrun", "ld", "-arch", arch, "-ios_version_min", "6.0", "-syslibroot", sdk,
               "-ObjC", "-o", thin, *objects, "-lobjc", "-lstdc++", "-lSystem"]
    for framework in FRAMEWORKS:
        command.extend(["-framework", framework])
    for framework in ("AdSupport", "StoreKit"):
        command.extend(["-weak_framework", framework])
    subprocess.run(command, check=True)
    # Verify that app code, the UIKit wrapper and both libraries reached the
    # linked executable. A defined symbol in nm has a concrete section.
    symbols = subprocess.check_output(["xcrun", "nm", "-m", thin], text=True)
    defined = {line.split()[-1] for line in symbols.splitlines() if " (__" in line}
    required = {"_main", "_viewGameConstruct", "_viewGameFrame", "_game_frame",
                "_OBJC_CLASS_$_dot_AppDelegate", "_OBJC_CLASS_$_dot_EAGLView",
                "_OBJC_CLASS_$_ALSource", "_OBJC_CLASS_$_GADBannerView"}
    if required - defined:
        raise ValueError(f"{arch} is missing linked definitions: {sorted(required - defined)}")
    print(f"Linked {arch} from source, including {len(sdk_inputs)} AdMob source inputs", flush=True)
    return thin


def game_resource(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        return False
    if len(path.parts) == 2 and path.parent.suffix == ".lproj":
        return path.suffix == ".strings"
    return len(path.parts) == 1 and (name in BUNDLE_FILES or path.suffix in {".png", ".caf", ".aif"})


def resources(source):
    if source.is_dir():
        items = {p.relative_to(source).as_posix(): p.read_bytes() for p in source.rglob("*")
                 if p.is_file() and game_resource(p.relative_to(source).as_posix())}
    else:
        with zipfile.ZipFile(source) as archive:
            items = {name: archive.read(entry) for entry in archive.infolist()
                     if entry.filename.startswith(BUNDLE_PREFIX)
                     and game_resource(name := entry.filename[len(BUNDLE_PREFIX):])}
    required = REQUIRED_ASSETS | {"Info.plist"}
    if required - items.keys():
        raise ValueError(f"missing Flap.app resources: {sorted(required - items.keys())}")
    info = plistlib.loads(items["Info.plist"])
    if info.get("CFBundleExecutable") != "flap":
        raise ValueError("expected Flap.app's Info.plist with executable name 'flap'")
    # The archive is unsigned and was built locally. Discard the old signing
    # resource rules and the App Store build-machine and toolchain stamps.
    for key in list(info):
        if key.startswith("DT") or key in ("BuildMachineOSBuild", "CFBundleResourceSpecification"):
            del info[key]
    items["Info.plist"] = plistlib.dumps(info, fmt=plistlib.FMT_BINARY)
    return items


def write_member(archive, name, data, mode):
    item = zipfile.ZipInfo(BUNDLE_PREFIX + name)
    item.create_system = 3
    item.external_attr = (0o100000 | mode) << 16
    archive.writestr(item, data, compress_type=zipfile.ZIP_DEFLATED)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sdk", type=Path, default=ROOT / ".toolchains/iPhoneOS7.0.sdk")
    parser.add_argument("--clang", type=Path, default=ROOT / ".toolchains/apple502/bin/clang")
    parser.add_argument("--assets", type=Path, default=ROOT / "assets")
    parser.add_argument("--output", type=Path, default=ROOT / "build/Flappy Bird editable.ipa")
    args = parser.parse_args()
    sdk = args.sdk.resolve()
    if not (sdk / "usr/lib/libSystem.dylib").is_file():
        parser.error("supply a full iPhoneOS7.0.sdk with --sdk or run tools/get_ios7_headers.py --full")
    if not args.clang.is_file():
        parser.error("install tools/get_apple502.py or supply --clang")
    output = args.output.resolve()
    if output.suffix.lower() != ".ipa" or output in (args.assets.resolve(), (ROOT / "Flappy Bird v1.2.ipa").resolve()):
        parser.error("choose an output .ipa separate from the input")
    assets = resources(args.assets)
    output.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=output.parent) as directory:
        work = Path(directory)
        slices = [build_slice(arch, work, sdk, args.clang.resolve()) for arch in ARCHES]
        executable = work / "flap"
        subprocess.run(["xcrun", "lipo", "-create", *slices, "-output", executable], check=True)
        subprocess.run(["xcrun", "lipo", executable, "-verify_arch", *ARCHES], check=True)
        archive_path = work / "editable.ipa"
        with zipfile.ZipFile(archive_path, "w") as archive:
            for name, data in sorted(assets.items()):
                write_member(archive, name, data, 0o644)
            write_member(archive, "flap", executable.read_bytes(), 0o755)
        os.replace(archive_path, output)
    print(f"Wrote unsigned {output}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        sys.exit(f"build_game: {error}")
