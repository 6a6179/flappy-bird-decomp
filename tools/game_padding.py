"""Assembler alignment within the original game translation units."""

from functools import lru_cache
import re
import subprocess

from verify import ROOT


def function_alignments(row, clang):
    """Read the function alignment directives emitted for this compiler profile."""
    return _function_alignments(row.arch, row.source, row.flags, row.toolchain, clang)


@lru_cache(maxsize=None)
def _function_alignments(arch, source, flags, toolchain, clang):
    assembler = [] if toolchain == "system" else ["-integrated-as"]
    command = [clang, "-target", f"{arch}-apple-ios7.0", "-mthumb", "-Os",
               "-ffreestanding", "-isysroot", "/", *assembler, *flags,
               "-gdwarf-2", "-S", source, "-o", "-"]
    asm = subprocess.run(command, check=True, cwd=ROOT, stdout=subprocess.PIPE, text=True).stdout
    alignments = {}
    alignment = None
    in_text = False
    for line in asm.splitlines():
        line = line.strip()
        if line.startswith(".section"):
            in_text = bool(re.match(r"\.section\s+__TEXT,__(?:text|textcoal_nt|StaticInit)(?:,|$)", line))
            alignment = None
            continue
        if not in_text:
            continue
        match = re.match(r"\.(?:align|p2align)\s+(\d+)\b", line)
        if match:
            alignment = 1 << int(match[1])
            continue
        # Historical ARM assembly can omit both .code and .thumb_func.
        # A symbol label consumes the alignment directive, debug labels and
        # the local basic-block labels can't inherit it from the function.
        label = re.fullmatch(r'(?:"([^"]+)"|([a-zA-Z_$][\w.$]*)):\s*(?:@.*)?', line)
        if label:
            name = label[1] or label[2]
            if alignment is not None and name.startswith(("_", "-[", "+[")):
                alignments[name] = alignment
            alignment = None
    return alignments


def game_assembler_fill(row, next_row, end_address, gap, next_alignment):
    """Return assembler-owned byte count; ld64 fills any remaining gap."""
    if gap < 0 or (end_address | gap) & 1:
        raise ValueError("invalid Thumb game padding range")
    if not gap:
        return 0

    # main.m precedes AppDelegate.m. Each of the three C++ stream constructors
    # occupies __TEXT,__StaticInit, separate from its translation unit's methods.
    if row.symbol in ("_main", "__GLOBAL__I_a"):
        return 0
    if next_row is None:
        raise ValueError("unknown successor to a game function with trailing alignment")
    if next_row.symbol == "__GLOBAL__I_a":
        return 0

    # The engine's numbered and sparkle pools instantiate the same C++ object
    # pool for different element classes. viewGameSetup constructs them in that
    # order and installs their two distinct vtables (layout/scene.tsv). Apple
    # Clang emits the shared pool initialization template in __textcoal_nt.
    # Its number and sparkle instantiations match both original function bodies
    # on both CPUs, placing the first specialization in a new input section.
    if next_row.symbol == "_init_number_pool":
        return 0

    if not next_alignment or next_alignment & (next_alignment - 1):
        raise ValueError(f"missing or invalid assembler alignment for {next_row.symbol}")
    return min(gap, -end_address % next_alignment)
