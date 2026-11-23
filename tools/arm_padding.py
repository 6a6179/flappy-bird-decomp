"""Generate the alignment between ARM functions from compiler and linker layout."""
import re

from game_padding import function_alignments, game_assembler_fill


# LLVM's ARMv7 assembler uses architectural NOPs for .align. ld64-224.1's
# OutputFile::writeAtoms uses the preceding atom's instruction set when calling
# copyNoOps between atoms; the latter emits mov r8,r8 or mov r0,r0.
ASSEMBLER_NOP = {True: bytes.fromhex("00bf"), False: bytes.fromhex("00f020e3")}
LINKER_NOP = {True: bytes.fromhex("c046"), False: bytes.fromhex("0000a0e1")}


def encode_padding(thumb, gap, assembler_size):
    unit = len(ASSEMBLER_NOP[thumb])
    if min(assembler_size, gap - assembler_size) < 0 or (gap % unit or assembler_size % unit):
        raise ValueError("invalid ARM code alignment")
    return ASSEMBLER_NOP[thumb] * (assembler_size // unit) + LINKER_NOP[thumb] * ((gap - assembler_size) // unit)


def method_owner(row):
    if row is None:
        return None
    match = re.match(r"^[+-]\[([^ ]+) ", row.symbol)
    return match[1] if match else None


class CodePadding:
    def __init__(self, image, clangs):
        self.image = image
        self.clangs = clangs
        self.rows = {}
        self.input_fill = {}

    def observe(self, row, rebuilt, extents):
        """Save the assembler's fill after the DWARF body, before the next function."""
        self.rows[row.address] = row
        symbol = rebuilt.symbols[row.symbol]
        start = symbol.addr & ~1
        end = extents[start]
        gap = self.image.ends[row.address] - row.address - (end - start)
        if gap <= 0:
            return
        limit = min((addr for addr in extents if addr >= end), default=rebuilt.text.addr + rebuilt.text.size)
        available = rebuilt.text_bytes(end, min(gap, limit - end))
        nop = ASSEMBLER_NOP[bool(symbol.description & 8)]
        count = 0
        while available.startswith(nop, count):
            count += len(nop)
        self.input_fill[row.address] = count

    def alignment(self, row):
        if row is None:
            return None
        return function_alignments(row, self.clangs[row.toolchain]).get(row.symbol)

    def complete(self, compiled, game_entries):
        """Return full slot contents and an independent count of generated padding bytes."""
        result = dict(compiled)
        size = 0
        for address, body in compiled.items():
            end = address + len(body)
            next_address = self.image.ends[address]
            gap = next_address - end
            if not gap:
                continue
            if gap < 0 or gap >= 1 << self.image.text.align or address not in self.input_fill:
                raise ValueError(f"unexplained trailing extent at {end:#x}")
            row = self.rows[address]
            following = self.rows.get(next_address)
            if address in game_entries:
                source_bytes = game_assembler_fill(row, following, end, gap, self.alignment(following))
            else:
                source_bytes = self.input_fill[address]
                owner = method_owner(row)
                if source_bytes < gap and owner and owner == method_owner(following):
                    # Methods of one implementation originally shared an input
                    # section, even when their recovered sources are in different
                    # files. Reapply the successor's own .align at placement.
                    alignment = self.alignment(following)
                    if not alignment:
                        raise ValueError(f"missing assembler alignment for {following.symbol}")
                    source_bytes = max(source_bytes, min(gap, -end % alignment))
            fill = encode_padding(self.image.starts[address], gap, source_bytes)
            if fill != self.image.text_bytes(end, gap):
                raise ValueError(f"generated alignment differs after {row.symbol} at {end:#x}")
            result[address] += fill
            size += len(fill)
        return result, size
