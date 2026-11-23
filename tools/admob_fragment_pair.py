"""The single two-instruction outline in the AdMob 6.8 signal object."""
from dataclasses import dataclass
import struct

from admob_inline_dispatch import branch, dispatch_words, movable_instruction


@dataclass(frozen=True)
class PairMove:
    offset: int
    stub: int
    selector: int
    alternate: int
    consumed = 8
    growth = -4

    @classmethod
    def parse(cls, text):
        kind, *args = text.split(":")
        if kind != "pair" or len(args) != 4:
            raise ValueError("expected pair:offset:stub:selector:alternate")
        return cls(*(int(arg, 0) for arg in args))

    def emit(self, instructions, site_vm, resume_vm):
        if len(instructions) != 2 or not all(map(movable_instruction, instructions)):
            raise ValueError("expected two position-independent compiler instructions")
        if resume_vm != site_vm + 4:
            raise ValueError("incorrect continuation for two-instruction outline")
        # The compiler's two adjacent words run in their original order before
        # the fixed vendor dispatch. The branch replacing them occupies one word.
        dispatch = dispatch_words(self.stub + 8, self.selector, resume_vm, self.alternate)
        words = [*instructions, *dispatch]
        return struct.pack("<I", branch(site_vm, self.stub)), struct.pack("<12I", *words)
