"""Recover ld64's trailing Thumb-to-ARM import islands from their callers."""

from bisect import bisect_left
from collections import defaultdict
import struct

from linkmatch import Layout, object_layout, word


def thumb_tail_target(instruction, pc):
    """Decode an unconditional Thumb-2 B.W; BL and BLX have different semantics."""
    first, second = struct.unpack("<HH", instruction)
    if first & 0xf800 != 0xf000 or second & 0xd000 != 0x9000:
        return None
    sign = first >> 10 & 1
    i1 = 1 ^ sign ^ (second >> 13 & 1)
    i2 = 1 ^ sign ^ (second >> 11 & 1)
    delta = (-(sign << 24) | i1 << 23 | i2 << 22 | (first & 0x3ff) << 12
             | (second & 0x7ff) << 1)
    return pc + 4 + delta


class LinkerIslands:
    def __init__(self, image):
        self.image = image
        self.slots = set(sorted(image.starts)[-10:])
        if len(self.slots) != 10 or any(not image.starts[a] or a % 4 or image.ends[a] - a != 12
                                        for a in self.slots):
            raise ValueError("expected ten aligned 12-byte Thumb island slots at the end of __text")

        # Only read Mach-O metadata here. The lazy import stub for a symbol
        # is fixed by its indirect-symbol index and the section's stub stride.
        layout = Layout(image.data)
        indirect = word(image.data, layout.commands[11] + 56)
        symbol_table = word(image.data, layout.commands[2] + 8)
        stubs = layout.by_name["__symbolstub1"]
        if stubs.segment != "__TEXT" or stubs.stride != 4 or stubs.size % stubs.stride:
            raise ValueError("invalid ARM import stub section")
        self.stubs = defaultdict(set)
        for i in range(stubs.size // stubs.stride):
            index = word(image.data, indirect + 4 * (stubs.indirect + i))
            if index >= len(layout.names) or image.data[symbol_table + 12 * index + 4] != 1:
                raise ValueError("ARM stub does not reference an undefined external symbol")
            self.stubs[layout.names[index]].add(stubs.addr + stubs.stride * i)
        self.calls = defaultdict(set)

    def observe(self, row, rebuilt, length):
        """Record the imported symbol and the original destination of the same call."""
        if not self.image.starts[row.address] or row.address in self.slots:
            return
        obj = object_layout(rebuilt.data)
        start = rebuilt.symbols[row.symbol].addr
        relocs = obj.relocations[rebuilt.text.name]  # includes C++ __StaticInit
        i = bisect_left(relocs, (start,))
        while i < len(relocs):
            pc, flags, desc, _ = relocs[i]
            if pc + 4 > start + length:
                break
            i += 1
            # External, PC-relative ARM_THUMB_RELOC_BR22, 32-bit, no addend.
            if flags >> 31 or desc >> 24 != 0x6d:
                continue
            name = obj.names[desc & 0xffffff]
            if name not in self.stubs or thumb_tail_target(rebuilt.text_bytes(pc, 4), pc) != 0:
                continue
            linked_pc = row.address + pc - start
            slot = thumb_tail_target(self.image.text_bytes(linked_pc, 4), linked_pc)
            if slot in self.slots:
                self.calls[slot].add(name)

    def generate(self):
        """Encode the interworking sequence without reading any island instructions or literals."""
        if self.calls.keys() != self.slots:
            missing = sorted(self.slots - self.calls.keys())
            raise ValueError("missing source tail-call evidence for " + ", ".join(map(hex, missing)))
        result = {}
        used = set()
        for slot, names in self.calls.items():
            if len(names) != 1:
                raise ValueError(f"conflicting imported symbols for island {slot:#x}")
            name, = names
            if name in used or len(self.stubs[name]) != 1:
                raise ValueError(f"ambiguous island or indirect stub for {name}")
            used.add(name)
            stub, = self.stubs[name]
            # ldr.w ip, [pc, #4]; add ip, pc; bx ip. The ADD at slot+4
            # reads slot+8 as PC. The aligned target address switches to ARM.
            if stub % 4:
                raise ValueError(f"unaligned ARM import stub for {name}")
            result[slot] = struct.pack("<4HI", 0xf8df, 0xc004, 0x44fc, 0x4760,
                                       (stub - (slot + 8)) & 0xffffffff)
        return result

    def verify(self):
        result = self.generate()
        for slot, body in result.items():
            if self.image.text_bytes(slot, len(body)) != body:
                raise ValueError(f"generated linker island differs at {slot:#x}")
        return result
