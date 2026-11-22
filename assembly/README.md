# Fixed-layout assembly

The two gzip files contain standalone assembly listings of `__TEXT,__text`. Unpack either one with `gzip -dc assembly/armv7.s.gz > /tmp/armv7.s` and search for any original virtual address or Objective-C method name. Each function has a label at its entry. Branches reference local labels or carry a fixed displacement and the original destination address. Calls into import stubs include the imported symbol name.

| Slice | Original VM start | Mnemonics | Bytes from mnemonics | Literal, table and data-alignment bytes | Total bytes |
| --- | --- | ---: | ---: | ---: | ---: |
| ARMv7 | `0x00009e90` | 201,276 | 750,248 | 1,772 | 752,020 |
| ARMv7s | `0x0000a020` | 201,145 | 749,888 | 1,752 | 751,640 |

The mnemonic counts include alignment NOPs encoded by the original compiler. Every instruction in both listings assembles from a mnemonic. Data directives preserve literal words and the linker’s jump tables. The verifier requires the entire section to match its reference SHA-256 and checks that the object has zero relocations in `__text`.

## Mixed-source rebuild

`python3 tools/verify.py --rebuild 'build/Flappy Bird.ipa'` uses the matched C and Objective-C functions as the source of their machine code. The build writes the compiler-produced, relocation-resolved bodies to a temporary binary. It generates a fixed-layout assembly unit that includes those bodies with `.incbin` and assembles the remaining instructions, literals and alignment from these listings. A fallback branch or jump table can still refer to a label inside a compiled body. The build checks the combined section digest before packaging the executable.

## Assemble offline

From the project root on macOS with Python 3.10+ and Xcode command-line tools, run

```sh
python3 tools/assembly.py assemble --arch armv7 --output /tmp/flap-armv7.text
python3 tools/assembly.py assemble --arch armv7s --output /tmp/flap-armv7s.text
```

These commands read the checked-in assembly and write raw code sections. They can run without the IPA or Ghidra. The output preserves the original virtual layout and references data, stubs and dynamic bindings elsewhere in the original Mach-O image.

To regenerate the assembly listings from the reference IPA, run `python3 tools/assembly_generate.py`. It reads the linker's ARM/Thumb function entries and data-in-code table, identifies additional PC-relative literal loads, disassembles the code, and checks a full byte comparison before publishing each listing.
