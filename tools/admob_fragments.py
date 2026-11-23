"""Reproduce the instruction outlining in AdMob 6.8's ARM objects.

A row in matches/fragments gives the linked entry, semantic source, function,
compiler flags, compiler, and the placements recovered from the vendor object's
local labels. Plain offsets outline a single instruction. The literal, dispatch
and pair tags describe variable-size rewrites in compiler-body coordinates.
All application instructions and literal constants come from the compiler.
"""
from dataclasses import dataclass
import shlex
import struct
from typing import Optional

from admob_arm_layout import ArmLayout, LiteralLoad
from admob_fragment_pair import PairMove
from admob_inline_dispatch import InlineDispatch, branch, dispatch_words, movable_instruction
from linkmatch import link_function


@dataclass(frozen=True)
class Move:
    offset: int
    stub: int
    selector: Optional[int] = None
    alternate: Optional[int] = None
    consumed = 4
    growth = 0

    def emit(self, instructions, site, resume):
        instruction, = instructions
        if not movable_instruction(instruction):
            raise ValueError(f"unsupported displaced ARM instruction {instruction:#x}")
        words = stub_words(self, instruction, resume)
        return struct.pack("<I", branch(site, self.stub)), struct.pack(f"<{len(words)}I", *words)

    @classmethod
    def parse(cls, text):
        fields = tuple(int(value, 0) for value in text.split(":"))
        if len(fields) not in (2, 4):
            raise ValueError("expected offset:stub or offset:stub:selector:alternate")
        return cls(*fields)


def parse_change(entry):
    if entry.startswith("literal:"):
        return LiteralLoad.parse(entry)
    if entry.startswith("dispatch:"):
        return InlineDispatch.parse(entry)
    if entry.startswith("pair:"):
        return PairMove.parse(entry)
    return Move.parse(entry)


def declared_fragments(root):
    from verify import HISTORICAL, Match, SLICE_SHA256

    for path in sorted((root / "matches" / "fragments").glob("*.tsv")):
        for lineno, line in enumerate(path.read_text().splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            try:
                arch, address, source, symbol, flags, compiler, placement = line.split("\t")
                if arch not in SLICE_SHA256 or compiler not in HISTORICAL:
                    raise ValueError("unknown CPU or compiler")
                moves = tuple(parse_change(entry) for entry in placement.split(","))
                yield Match(arch, int(address, 0), 0, root / source, symbol,
                            tuple(shlex.split(flags)), compiler), moves
            except ValueError as exc:
                raise ValueError(f"{path.name}:{lineno}: {exc}") from exc


def stub_words(move, instruction, resume):
    if move.selector is None:
        return [instruction, branch(move.stub + 4, resume)]
    return [instruction, *dispatch_words(move.stub + 4, move.selector, resume, move.alternate)]


def outline(original, address, body, moves, relocations):
    """Outline compiler words and split output at the original atom boundaries."""
    layout = ArmLayout(len(body), moves)
    return emitted_parts(original, address, body, layout, relocations, set())


def emitted_parts(original, address, body, layout, relocations, pool):
    parts = layout.render(address, body, relocations, pool)
    for start, data in parts.items():
        if original.starts.get(start) is not False or original.ends[start] != start + len(data):
            raise ValueError(f"outlined extent or instruction state differs at {start:#x}")
    return parts


def verify_fragments(row, moves, original, rebuilt, extents):
    symbol = rebuilt.symbols.get(row.symbol)
    if not symbol or symbol.section != rebuilt.text.index or symbol.description & 8:
        raise ValueError("outlined source function missing from compiled ARM text")
    start = symbol.addr
    if start not in extents:
        raise ValueError("missing DWARF extent for outlined source function")
    length = extents[start] - start
    layout = ArmLayout(length, moves)
    body = link_function(rebuilt.data, original.data, start, row.address, length,
                         placed_address=lambda pc: row.address + layout.map_offset(pc - start))
    relocations = {pc - start for pc, size in rebuilt.relocations if start <= pc < start + length}
    pool = set()
    for lo, hi in rebuilt.literal_ranges:
        if lo < start + length and start < hi:
            if lo < start or hi > start + length or (lo | hi) % 4:
                raise ValueError("unsupported unaligned or cross-function ARM data")
            pool.update(range(lo - start, hi - start, 4))
    parts = emitted_parts(original, row.address, body, layout, relocations, pool)
    for address, data in parts.items():
        expected = original.text_bytes(address, len(data))
        if data != expected:
            idx = next(i for i, (a, b) in enumerate(zip(data, expected)) if a != b)
            raise ValueError(f"outlined bytes differ at {address+idx:#x}")
    return parts, length
