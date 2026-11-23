"""Apply AdMob's ARM instruction layout to a compiler-emitted function."""

from dataclasses import dataclass
import struct


@dataclass(frozen=True)
class LiteralLoad:
    """Expand a direct load of a compiler pool word into the SDK's indirect load."""

    offset: int
    consumed = 4
    growth = 12

    @classmethod
    def parse(cls, text):
        tag, offset = text.split(":")
        if tag != "literal":
            raise ValueError("expected literal:offset")
        return cls(int(offset, 0))


def literal_load(word):
    # A32 immediate-offset, pre-indexed, word LDR with Rn=PC and no writeback.
    return word & 0x0f7f0000 == 0x051f0000 and word >> 28 != 15


def pool_target(word, pc, scale=1):
    magnitude = (word & (0xff if scale == 4 else 0xfff)) * scale
    return pc + 8 + (magnitude if word & (1 << 23) else -magnitude)


class ArmLayout:
    def __init__(self, length, changes):
        if length <= 0 or length % 4 or not changes:
            raise ValueError("expected a nonempty A32 body and layout")
        self.length = length
        self.changes_size = any(change.growth for change in changes)
        self.changes = {}
        self.placed = {}
        cursor = 0
        growth = 0
        for change in sorted(changes, key=lambda item: item.offset):
            start = change.offset
            stop = start + change.consumed
            if start < cursor or start % 4 or stop > length or stop <= start:
                raise ValueError("overlapping or invalid ARM rewrite offset")
            self.changes[start] = change
            for off in range(cursor, start + 1, 4):
                self.placed[off] = off + growth
            growth += change.growth
            cursor = stop
        for off in range(cursor, length + 1, 4):
            self.placed[off] = off + growth

    def map_offset(self, offset):
        try:
            return self.placed[offset]
        except KeyError as exc:
            raise ValueError(f"ARM layout target lies outside the body or inside a rewrite: {offset:#x}") from exc

    def place_local(self, word, offset, pool):
        """Retarget local branches and unexpanded PC-relative loads after size changes."""
        if word >> 25 & 7 == 5:
            if word >> 28 == 15:
                raise ValueError("unsupported local A32 BLX immediate")
            displacement = ((word & 0xffffff) ^ 0x800000) - 0x800000
            target = offset + 8 + 4 * displacement
            if target in pool or target == self.length:
                raise ValueError("ARM branch points to data or the end of the input function")
            delta = self.map_offset(target) - (self.map_offset(offset) + 8)
            if delta % 4 or not -(1 << 25) <= delta < 1 << 25:
                raise ValueError("ARM local branch destination out of range")
            return (word & 0xff000000) | ((delta // 4) & 0xffffff)
        # Scalar VLDR literal uses the same PC bias with a word-scaled imm8.
        vldr = word & 0x0f3f0e00 == 0x0d1f0a00
        if literal_load(word) or vldr:
            scale = 4 if vldr else 1
            mask = 0xff if vldr else 0xfff
            target = pool_target(word, offset, scale)
            if target not in pool:
                raise ValueError("ARM literal load does not point into compiler pool data")
            delta = self.map_offset(target) - (self.map_offset(offset) + 8)
            if abs(delta) % scale or abs(delta) // scale > mask:
                raise ValueError("ARM literal pool out of range")
            return (word & ~(mask | (1 << 23))) | ((delta >= 0) << 23) | (abs(delta) // scale)
        return word

    def render(self, address, body, relocations, pool):
        """Emit main code and stubs from linked compiler words and placement metadata."""
        if len(body) != self.length or address % 4:
            raise ValueError("invalid linked ARM body")
        main = bytearray()
        stubs = {}
        boundaries = [address]
        offset = 0
        while offset < self.length:
            word, = struct.unpack_from("<I", body, offset)
            change = self.changes.get(offset)
            if change is None:
                if self.changes_size and offset not in relocations and offset not in pool:
                    word = self.place_local(word, offset, pool)
                main.extend(struct.pack("<I", word))
                offset += 4
                continue

            stop = offset + change.consumed
            if any(pos in pool or pos in relocations for pos in range(offset, stop, 4)):
                raise ValueError("cannot rewrite a relocation or a compiler data word")
            pc = address + self.map_offset(offset)
            resume = address + self.map_offset(stop)
            if isinstance(change, LiteralLoad):
                if not literal_load(word) or word >> 28 != 14 or (word >> 12 & 15) == 15:
                    raise ValueError("expected an unconditional ARM word literal load")
                target = pool_target(word, offset)
                if target not in pool:
                    raise ValueError("expanded load does not point into compiler pool data")
                register = (word >> 12) & 15
                # LDR Rd,[PC,#4]; LDR Rd,[PC,Rd]; B resume; .long pool-(site+12)
                emitted = struct.pack("<4I", 0xe59f0004 | register << 12,
                                      0xe79f0000 | register << 12 | register, 0xea000000,
                                      (address + self.map_offset(target) - (pc + 12)) & 0xffffffff)
            else:
                if stop == self.length or change.stub % 4 or change.stub in stubs:
                    raise ValueError("invalid ARM stub or missing continuation")
                words = struct.unpack_from(f"<{change.consumed // 4}I", body, offset)
                emitted, stub = change.emit(words, pc, resume)
                stubs[change.stub] = stub
                boundaries.append(resume)
            if len(emitted) != resume - pc:
                raise ValueError("ARM rewrite size disagrees with placement")
            main.extend(emitted)
            offset = stop

        end = address + len(main)
        spans = [(address, end)] + [(start, start + len(data)) for start, data in stubs.items()]
        spans.sort()
        if any(first[1] > second[0] for first, second in zip(spans, spans[1:])):
            raise ValueError("overlapping ARM layout regions")
        for start, stop in zip(boundaries, boundaries[1:] + [end]):
            stubs[start] = bytes(main[start - address:stop - address])
        return stubs
