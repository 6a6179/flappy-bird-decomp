"""Regression checks for compiler-to-executable ARM address mapping."""

import struct
from types import SimpleNamespace
import unittest

from admob_arm_layout import ArmLayout, LiteralLoad
from linkmatch import relocate_function
from verify import CPU_ARM, Image


class ArmRelocationTests(unittest.TestCase):
    def test_half_difference_uses_the_mapped_add_pc_anchor(self):
        # MOVW/MOVT r1, #(object_target-(anchor+8)); LDR r2,[pc,#4];
        # ADD r1,pc,r1; BX lr; pool. Expanding LDR moves ADD by twelve bytes.
        start, entry, object_target = 0x100, 0x8000, 0x300
        anchor = start + 12
        before = object_target - (anchor + 8)
        code = struct.pack("<6I", 0xe3001000 | before, 0xe3401000, 0xe59f2004,
                           0xe08f1001, 0xe12fff1e, 0x76543210)
        relocations = [
            (start, 0x89000000, object_target, (0x81000000, anchor)),
            (start + 4, 0x99000004, object_target, (0x81000000 | before, anchor)),
        ]
        obj = SimpleNamespace(data=code, file_offset=lambda addr: addr - start,
                              section_at=lambda addr: SimpleNamespace(name="__text"),
                              relocations={"__text": relocations})
        layout = ArmLayout(len(code), [LiteralLoad(8)])
        # The wrong, unexpanded PC would raise the value to 0x10004, changing both halves.
        target = entry + 24 + 8 + 0xfff8
        ref = SimpleNamespace(target=lambda *_: target)
        relocated = relocate_function(obj, ref, start, entry, len(code),
                                      placed_address=lambda pc: entry + layout.map_offset(pc - start))
        low, high = struct.unpack_from("<II", relocated)
        self.assertEqual((low, high), (0xe30f1ff8, 0xe3401000))
        emitted = layout.render(entry, relocated, {0, 4}, {20})[entry]
        self.assertEqual(struct.unpack_from("<I", emitted, 24)[0], 0xe08f1001)

    def test_data_in_code_uses_object_addresses_and_executable_file_offsets(self):
        text_vm, text_file, table = 0x80, 0x200, 0x220
        for filetype, data_offset in [(1, text_vm + 4), (2, text_file + 4)]:
            with self.subTest(filetype=filetype):
                data = bytearray(table + 16)
                # A segment containing one text section, then LC_DATA_IN_CODE.
                struct.pack_into("<7I", data, 0, 0xfeedface, CPU_ARM, 9, filetype, 2, 140, 0)
                struct.pack_into("<II16s8I", data, 28, 1, 124, b"__TEXT",
                                 0, 0x1000, 0, len(data), 7, 5, 1, 0)
                struct.pack_into("<16s16s9I", data, 84, b"__text", b"__TEXT",
                                 text_vm, 16, text_file, 2, 0, 0, 0, 0, 0)
                struct.pack_into("<4I", data, 152, 0x29, 16, table, 16)
                struct.pack_into("<IHHIHH", data, table, data_offset, 4, 1, data_offset + 4, 4, 2)
                image = Image(bytes(data))
                self.assertEqual(image.literal_ranges, [(text_vm + 4, text_vm + 8),
                                                        (text_vm + 8, text_vm + 12)])
                self.assertEqual(image.literal_ends, {text_vm + 8})


if __name__ == "__main__":
    unittest.main()
