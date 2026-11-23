"""Generate the two-way ARM dispatcher found in the AdMob 6.8 archive."""
from dataclasses import dataclass
import struct
from typing import Optional


def branch(pc, target):
    delta = target - (pc + 8)
    if delta % 4 or not -(1 << 25) <= delta < 1 << 25:
        raise ValueError("unreachable ARM branch destination")
    return 0xea000000 | ((delta >> 2) & 0xffffff)


def movable_instruction(instruction):
    """Position-independent ARM AND, EOR and SUB forms present in these objects."""
    if instruction >> 28 != 14 or (instruction >> 21) & 15 not in (0, 1, 2):
        return False
    if (instruction >> 12) & 15 == 15 or (instruction >> 16) & 15 == 15:
        return False
    immediate = instruction & 0x0e000000 == 0x02000000
    register = instruction & 0x0e000010 == 0 and instruction & 15 != 15
    return immediate or register


def dispatch_words(site, selector, target, alternate):
    """Save scratch registers, select an arm and restore registers before jumping."""
    if selector not in (0, 12) or alternate is None:
        raise ValueError("unknown vendor dispatch form")
    first, second = (target, alternate) if selector == 0 else (alternate, target)
    end = site + 40
    return [
        0xe92d4018,             # push {r3,r4,lr}
        0xe3a03000 | selector,  # mov r3, #selector
        0xe08f4003,             # add r4, pc, r3
        0xe12fff14,             # bx r4
        0xe8bd4018,             # pop {r3,r4,lr}
        branch(site + 20, first),
        branch(site + 24, end),
        0xe8bd4018,
        branch(site + 32, second),
        branch(site + 36, end),
    ]


@dataclass(frozen=True)
class InlineDispatch:
    offset: int
    stub: int
    selector: int
    alternate: int
    stub_selector: Optional[int] = None
    stub_alternate: Optional[int] = None

    # A 40-byte dispatcher replaces a single four-byte compiler instruction.
    consumed = 4
    growth = 36

    @classmethod
    def parse(cls, text):
        fields = text.split(":")
        if len(fields) not in (5, 7) or fields[0] != "dispatch":
            raise ValueError("expected dispatch:offset:stub:selector:alternate[:stub_selector:stub_alternate]")
        return cls(*(int(value, 0) for value in fields[1:]))

    def emit(self, words, site, resume):
        instruction, = words
        if resume != site + 40:
            raise ValueError("inline dispatcher must resume immediately after its two arms")
        if not movable_instruction(instruction):
            raise ValueError(f"unsupported displaced ARM instruction {instruction:#x}")
        words = dispatch_words(site, self.selector, self.stub, self.alternate)
        if self.stub_selector is None:
            if self.stub_alternate is not None:
                raise ValueError("missing selector for nested dispatcher")
            tail = [branch(self.stub + 4, resume)]
        else:
            tail = dispatch_words(self.stub + 4, self.stub_selector, resume, self.stub_alternate)
        return struct.pack("<10I", *words), struct.pack(f"<{1 + len(tail)}I", instruction, *tail)
