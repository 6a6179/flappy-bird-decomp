# ObjectAL audio library

The supplied IPA includes Karl Stenerud's ObjectAL license and Objective-C classes. The source files here come from the iOS library at ObjectAL-for-iPhone commit `9a33f7802c86bbbac41dc65539d88f617b96d7ae` (April 15, 2013). The headers and implementation files share one directory to support the project's original unqualified header imports. The files retain their upstream content and license. [ObjectAL source](https://github.com/kstenerud/ObjectAL-for-iPhone/tree/9a33f7802c86bbbac41dc65539d88f617b96d7ae/ObjectAL) · [License](LICENSE.ObjectAL.txt)

The verifier compiles these sources and checks individual routines against the IPA at their original addresses. The resulting code reproduces the original buffer-slice parent retain, the iOS interruption notification constants and the synchronous audio preload methods. Upstream changed the notification constants and enabled block-based preloading on April 16, then changed the buffer retain on April 18. The exact checkout used by the game developer is unknown. [April 16 changes](https://github.com/kstenerud/ObjectAL-for-iPhone/commit/40d100d) · [April 18 changes](https://github.com/kstenerud/ObjectAL-for-iPhone/commit/ebd5a1e462f8511dd302319443617fdcc1289f81)

All 974 function bodies in the ObjectAL interval match on each architecture. The build uses the compiler from Xcode 5.0.2 (clang-500.2.79), size optimization, hosted C library semantics, iOS 7.0 framework headers, manual reference counting, disabled Objective-C exceptions and a minimum deployment target of iOS 6.0. Source checksouts on a new machine can use these commands from the project root. The compiler installer verifies the archived Apple binary and its builtin headers. [Xcode 5.0.2 archive](https://archive.org/download/xcode_archives/Xcode_5.0.2.dmg)

```sh
python3 tools/get_apple502.py
python3 tools/get_ios7_headers.py --sdk /path/to/iPhoneOS7.0.sdk
```

Running the header installer without `--sdk` downloads the five parts of a pinned 431 MB SDK archive, verifies the assembled SHA-256 and installs the public headers under `.toolchains/iphoneos7`. An existing copy of that archive can be supplied with `--archive`. [SDK archive mirror](https://github.com/qianjigui/iOS-sdks/tree/189a487850e3351cf624b5cef9c8317138c89b05/iPhoneOS7.0.sdk)
