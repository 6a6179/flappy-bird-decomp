# Flappy Bird 1.2 for iOS

This is an editable C, C++ and Objective-C reconstruction of Dong Nguyen’s last iOS release. The game builds for the original ARMv7 and ARMv7s devices. The repository includes the game assets, ObjectAL audio sources and two build targets.

## Build the editable game

On macOS with Xcode command-line tools and Python 3.10 or newer, run

```sh
make setup-editable
make editable
```

The result is `build/Flappy Bird editable.ipa`. This target compiles and links the game, its iOS wrapper, ObjectAL and the bundled Google Mobile Ads SDK, including its iAd adapter, from source. It takes the artwork, sounds and bundle files from `assets/`. The unpacked source archive builds this target without the original IPA or an AdMob library. Edit a source file or a resource and rerun `make editable`. The output is unsigned. Installing it on a compatible 32-bit iOS device requires signing.

Setup installs the Apple compiler from Xcode 5.0.2 (build 5A3005) and the iPhoneOS 7.0 SDK. The compiler needs Rosetta on Apple silicon. For existing downloads, the compiler setup script accepts `--xcode` and the SDK setup script accepts `--sdk`. [Xcode archive](https://archive.org/details/xcode_archives)

## Where to edit

| Area | Files |
| --- | --- |
| Bird physics, pipes, collisions, input and scoring | [gameplay.c](src/gameplay.c), [gameplay.h](src/gameplay.h) |
| Game objects, construction and asset loading | [game_objects.h](src/game_objects.h), [gameplay_init.c](src/gameplay_init.c) |
| Score panel, medals, title and game-over overlays | [scene.c](src/scene.c), [scene_numbers.c](src/scene_numbers.c), [scene_overlays.c](src/scene_overlays.c) |
| Sprites, easing and animation | [native.c](src/native.c), [native.h](src/native.h) |
| OpenGL setup, atlas, fonts and frame loop | [renderer.c](src/renderer.c), [renderer_atlas.c](src/renderer_atlas.c), [engine_frame.c](src/engine_frame.c) |
| UIKit startup, input, display link, sound and Game Center | [app_delegate.m](src/app_delegate.m), [view.m](src/view.m), [view_commands.h](src/view_commands.h) |
| Advertising and mediation | [Banner](src/gad_banner.m), [request](src/gad_request.m), [iAd adapter](src/gad_adapter_iad.m), [SDK methods and accessors](src/library_admob.m) |
| Ad SDK class layouts, protocols and shared constants | [Classes](src/editable_admob_runtime.m), [protocols](src/editable_admob_protocols.h), [constants](src/editable_admob_data.m) |
| Graphics and sound files | [assets](assets/), [texture atlas](assets/atlas.txt) |
| Third-party source provenance | [ObjectAL](src/objectal/README.md), [Google Toolbox for Mac and SBJSON](src/library_upstream/README.md) |

Names of stripped native functions and fields were inferred from their behavior. The Objective-C runtime preserves the original class and selector names.

Several recovered files implement methods on the same AdMob class. The editable build compiles each file and combines its method entries under a single class definition before linking. Edit method bodies in their implementation files. For a change to an instance variable or property, update its canonical class declaration and the implementations that use it. [Objective-C build step](tools/editable_objc.py)

## Reproduce the shipped IPA

Place the supplied `Flappy Bird v1.2.ipa` beside this README. Run the following on macOS with CMake and the Xcode command-line tools.

```sh
make setup
make
cmp 'Flappy Bird v1.2.ipa' 'build/Flappy Bird.ipa'
```

The iAd adapter uses Apple LLVM 4.1 from Xcode 4.5. `make setup` builds that compiler from Apple's published `clang-421.11.65` source. [Apple compiler source](https://github.com/apple-oss-distributions/clang/tree/clang-421.11.65) The October 2012 iAd adapter’s debug symbols identify that compiler and preserve the three local size declarations used by `usePortraitIdentifier`. [Original adapter archive](https://github.com/dearhui/Adwhirl-iOS/blob/0ff48b829/AdNetwork/GoogleAdMobAdsSdkiOS/MediationLibrary/LibAdapterIAd-Oct42012/libAdapterIAd.a)

The matching build regenerates every byte of `__TEXT,__text` on both architectures from the reconstructed sources, compiler output and linker layout. It also rebuilds 14 game virtual tables and portions of the view’s Objective-C metadata. It writes those ranges into a copy of the original executable. That copy supplies the Mach-O headers, other Objective-C data, string constants, import tables and original signature. The archive reuses the original resources and ZIP metadata. The rebuilt IPA has SHA-256 `b306da69c5555b1e55aab1fd2e41708c4b1b53cb1893bc9a7f6bcc84d08e57bb`.

| Slice | Contiguous compiler matches | C functions with SDK layout changes (entries) | Generated linker stubs | Total entries reproduced | Code bytes reproduced |
| --- | ---: | ---: | ---: | ---: | ---: |
| ARMv7 | 3,058 | 27 (101) | 10 | 3,169 / 3,169 | 752,020 / 752,020 (100%) |
| ARMv7s | 3,058 | 27 (101) | 10 | 3,169 / 3,169 | 751,640 / 751,640 (100%) |

Each slice contains 3,085 reconstructed functions. The SDK moved instructions from some functions into separate blocks and expanded some loads from literal pools. The verifier applies those layout changes to freshly compiled code and compares every resulting block at its original address. It also generates the ten Thumb-to-ARM linker stubs from their callers and the import table. Alignment accounts for the last 1,222 bytes on ARMv7 and 1,218 on ARMv7s. A missing function, incorrect relocation or different padding byte fails the build. [SDK layout manifests](matches/fragments/) · [Linker stubs](tools/linker_islands.py) · [Alignment](tools/arm_padding.py)

The first 181 linker entries cover app startup, the iOS wrapper and the native game. The verifier requires all 181 to reproduce from compiled source on each CPU. For the main game loop, the matching configuration uses register constraints that emit no instructions. They preserve the original compiler’s repeated collision check and register choices. The editable build uses the shared gameplay logic with ordinary register allocation. All 974 functions in the ObjectAL interval match on both CPUs. [Per-function manifests](matches/)

The advertising SDK sources cover the serialized ad requests, network fetcher, JavaScript message handling, mediation, delegates and statistics. The native code includes the SDK’s digest and stream cipher routines. During the matching build, every claimed method must resolve to its original class and selector, even when two method bodies contain identical instructions. [Ad fetcher](src/gad_fetcher.m) · [Mediation](src/gad_mediation_manager.m) · [MD5](src/gad_gesture_md5.c) · [SDK linker](tools/admob_objects.py)

`make verify` checks the matches without writing an IPA. `python3 tools/verify.py -v` prints each credited function. Verification compares the instruction mode, compiler-reported function extent, linked relocations and every byte in the body. The verifier also checks Objective-C method identities against runtime metadata. The complete-section check covers trailing alignment and compares the section’s SHA-256 independently of the archived assembly listings. [Link layout](layout/) · [Assembly listings](assembly/README.md)

## Test the builds

```sh
make test
make test-editable
```

Each target runs 2,017 comparisons per CPU against the original game under ARM emulation. Of these, 1,296 exercise both pipe pairs at, inside and outside the collision edges, with asymmetric upper and lower widths and three warmup states. The first compiles the gameplay module in isolation. The second executes the gameplay routines directly from the newly linked editable IPA. The cases cover flapping, scoring boundaries, collisions, game events, RNG state and the order and arguments of rendering and audio calls. Graphics and sound callbacks are observed at their interfaces. A device launch is a separate test.

`make test-editable` also compares Objective-C runtime metadata against the original and executes linked AdMob request and banner methods under ARM emulation. The banner checks use simulated iOS services. These comparison tests use the original IPA as a reference.

`make source-zip` packages the editable sources, assets and matching tools in `build/Flappy Bird source.zip`. The optional Ghidra listings can be regenerated for instruction-level investigation. [Decompiler notes](recovered/README.md)
