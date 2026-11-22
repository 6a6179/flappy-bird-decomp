# Flappy Bird 1.2 for iOS

This is an editable C, C++ and Objective-C reconstruction of Dong Nguyen’s last iOS release. The game builds for the original ARMv7 and ARMv7s devices. The repository includes the game assets, ObjectAL audio sources and two build targets.

## Build the editable game

On macOS with Xcode command-line tools and Python 3.10 or newer, run

```sh
make setup-editable
make editable
```

The result is `build/Flappy Bird editable.ipa`. This target compiles the game, its iOS wrapper and ObjectAL, links the Google Mobile Ads 6.8.0 static library, and packages the files in `assets/`. The unpacked source archive can build this target on its own after dependency setup. Edit the game or a resource and rerun `make editable`. The output is unsigned. Installing it on a compatible 32-bit iOS device requires signing.

Setup installs the Apple compiler from Xcode 5.0.2 (build 5A3005), the iPhoneOS 7.0 SDK and the version of AdMob named by the original app. The compiler needs Rosetta on Apple silicon. For existing downloads, the setup scripts accept `--xcode`, `--sdk`, or `--library` respectively. [Xcode archive](https://archive.org/details/xcode_archives) · [AdMob 6.8.0 dependency](https://github.com/floatinghotpot/cordova-plugin-admob/tree/adb32b97af2c2bd17b44165d45140b6eb8738297/src/ios)

## Where to edit

| Area | Files |
| --- | --- |
| Bird physics, pipes, collisions, input and scoring | [gameplay.c](src/gameplay.c), [gameplay.h](src/gameplay.h) |
| Game objects, construction and asset loading | [game_objects.h](src/game_objects.h), [gameplay_init.c](src/gameplay_init.c) |
| Score panel, medals, title and game-over overlays | [scene.c](src/scene.c), [scene_numbers.c](src/scene_numbers.c), [scene_overlays.c](src/scene_overlays.c) |
| Sprites, easing and animation | [native.c](src/native.c), [native.h](src/native.h) |
| OpenGL setup, atlas, fonts and frame loop | [renderer.c](src/renderer.c), [renderer_atlas.c](src/renderer_atlas.c), [engine_frame.c](src/engine_frame.c) |
| UIKit startup, input, display link, sound and Game Center | [app_delegate.m](src/app_delegate.m), [view.m](src/view.m), [view_commands.h](src/view_commands.h) |
| Graphics and sound files | [assets](assets/), [texture atlas](assets/atlas.txt) |
| Third-party source provenance | [ObjectAL](src/objectal/README.md), [GTMStringEncoding and SBJSON](src/library_upstream/README.md) |

Names of stripped native functions and fields were inferred from their behavior. The Objective-C runtime preserves the original class and selector names.

## Reproduce the shipped IPA

Place the supplied `Flappy Bird v1.2.ipa` beside this README. Run the following on macOS with CMake and the Xcode command-line tools.

```sh
make setup
make
cmp 'Flappy Bird v1.2.ipa' 'build/Flappy Bird.ipa'
```

The complete reference archive has SHA-256 `b306da69c5555b1e55aab1fd2e41708c4b1b53cb1893bc9a7f6bcc84d08e57bb`. This target verifies compiler-emitted function bodies at their original addresses. It links additional routines from the original AdMob library, rebuilds 14 game virtual tables and the view’s Objective-C metadata, and assembles the remaining instruction ranges. The reference supplies other binary sections, original resources, signatures and ZIP metadata. Changing an instruction in a claimed function makes verification fail.

| Slice | Whole functions matched from source | Compiler-emitted bytes in the code section | Additional whole functions linked from the AdMob library |
| --- | ---: | ---: | ---: |
| ARMv7 | 2,331 / 3,169 | 557,250 / 752,020 (74.100%) | 392 (85,860 bytes) |
| ARMv7s | 2,327 / 3,169 | 556,190 / 751,640 (73.997%) | 397 (86,476 bytes) |

The first 181 linker entries cover app startup, the iOS wrapper and the native game. The verifier requires all 181 to reproduce from compiled source on each CPU. For the main game loop, the matching configuration uses register constraints that emit no instructions. They preserve the original compiler’s repeated collision check and register choices. The editable build uses the shared gameplay logic with ordinary register allocation. All 974 functions in the ObjectAL interval match on both CPUs. The source manifests also cover portions of the advertising SDK, including its 256-byte block transform. [Per-function manifests](matches/)

`make verify` checks the matches without writing an IPA. `python3 tools/verify.py -v` prints each credited function. Verification compares the instruction mode, compiler-reported function extent, linked relocations and every byte in the body. The verifier also checks Objective-C method identities against runtime metadata. Coverage excludes trailing alignment bytes. [Link layout](layout/) · [Assembly listings](assembly/README.md)

## Test gameplay

```sh
make test
make test-editable
```

Each target runs 2,017 comparisons per CPU against the original game under ARM emulation. Of these, 1,296 exercise both pipe pairs at, inside and outside the collision edges, with asymmetric upper and lower widths and three warmup states. The first compiles the gameplay module in isolation. The second executes the gameplay routines directly from the newly linked editable IPA. The cases cover flapping, scoring boundaries, collisions, game events, RNG state and the order and arguments of rendering and audio calls. Graphics and sound callbacks are observed at their interfaces. A device launch is a separate test.

`make source-zip` packages the editable sources, assets and matching tools in `build/Flappy Bird source.zip`. The optional Ghidra listings can be regenerated for instruction-level investigation. [Decompiler notes](recovered/README.md)
