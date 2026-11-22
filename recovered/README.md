# Reading the decompiler output

Each architecture directory holds one row per function in the executable’s Mach-O `LC_FUNCTION_STARTS` table. Look up an Objective-C selector or virtual address in `index.tsv`, open the named listing and search for the address comment. The native game code appears in the first two listings in each directory. For example, search the ARMv7 index for `-[dot_EAGLView drawView:]` to find the frame callback at `0x0000b220`. Calls named `FUN_000…` lead to bodies at those addresses.

| Per slice | ARMv7 | ARMv7s |
| --- | ---: | ---: |
| Linker entries with C-like output | 3,169 | 3,169 |
| Entries named by Objective-C implementation metadata | 2,704 | 2,704 |
| ARM / Thumb entries | 1,938 / 1,231 | 1,938 / 1,231 |
| Entries with inline Ghidra warnings | 123 | 123 |

These listings contain unverified pseudocode. Ghidra inferred the types, calling signatures, variable names and control flow. Some Objective-C calls have incomplete arguments or targets. Ghidra’s message analyzer reported exceptions during the import. All 3,169 entry addresses in each slice passed the instruction-mode check and produced a body. The index’s `next_boundary` column gives the next linker entry or the end of `__text`. That span can include padding and literal pools.

## Regenerate

Use macOS with Xcode command-line tools, Python 3, JDK 25 and Ghidra 12.2. The release archive SHA-256 is `2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67`. On macOS the release requires a native decompiler build. The bundled `support/gradle/gradlew buildNatives` task builds the host tools when run from the `support/gradle` directory. [Ghidra 12.2 release](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.2_build)

From the project root, run

```sh
python3 tools/decompile.py --ghidra /path/to/ghidra_12.2_PUBLIC
```

To regenerate a single slice in a separate directory, append `--arch armv7 --out /tmp/flap-listings`. The driver extracts the executable to a temporary project, gets the ARM/Thumb bit from each raw linker start, checks the Objective-C implementation pointers against those starts, and seeds Ghidra’s disassembler before analysis. Both slices use Ghidra’s little-endian ARMv7 processor and APCS compiler specification.
