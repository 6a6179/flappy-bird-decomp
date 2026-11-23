"""Checks for the independent caller and import evidence behind ld64 islands."""
import struct
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from linker_islands import LinkerIslands, thumb_tail_target
from verify import Image, ROOT, original_images


class LinkerIslandsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ipa = ROOT / "Flappy Bird v1.2.ipa"
        if not ipa.is_file():
            raise unittest.SkipTest("requires the original IPA")
        cls.image = original_images(ipa)["armv7"]

    def setUp(self):
        self.islands = LinkerIslands(self.image)
        # Independent expectations for the original imports in linked order.
        self.names = ["_objc_msgSend", "_objc_setProperty_nonatomic", "__Block_object_assign",
                      "__Block_object_dispose", "___cxa_atexit", "__ZdlPv", "_glBindRenderbuffer",
                      "_sinf", "_exp2f", "_objc_sync_exit"]

    def test_evidence_comes_from_an_external_tail_relocation(self):
        # _easeFunction_sineOut ends in a B.W to the sinf island at offset 16.
        row = SimpleNamespace(address=0x11ddc, symbol="_easeFunction_sineOut")
        opcode = struct.pack("<HH", 0xf7ff, 0xbff6)
        self.assertEqual(thumb_tail_target(opcode, 16), 0)
        compiled = SimpleNamespace(data=b"object", text=SimpleNamespace(name="__text"),
                                   symbols={row.symbol: SimpleNamespace(addr=0)},
                                   text_bytes=lambda pc, size: opcode)
        obj = SimpleNamespace(names=["_sinf"], relocations={"__text": [(16, 16, 0x6d000000, None)]})
        with patch("linker_islands.object_layout", return_value=obj):
            for instruction in ((0xf7ff, 0xfff6), (0xf7ff, 0xbff7)):  # BL; B.W with an addend
                opcode = struct.pack("<HH", *instruction)
                self.islands.observe(row, compiled, 20)
                self.assertFalse(self.islands.calls)
            opcode = struct.pack("<HH", 0xf7ff, 0xbff6)
            self.islands.observe(row, compiled, 20)
            self.assertEqual(dict(self.islands.calls), {0xc1800: {"_sinf"}})

    def test_generated_bytes_are_independent_of_original_islands(self):
        calls = {slot: {name} for slot, name in zip(sorted(self.islands.slots), self.names)}
        self.islands.calls.update(calls)
        expected = self.islands.verify()
        data = bytearray(self.image.data)
        for slot in self.islands.slots:
            offset = self.image.text.offset + slot - self.image.text.addr
            data[offset:offset+12] = bytes(12)
        changed = LinkerIslands(Image(bytes(data)))
        changed.calls.update(calls)
        self.assertEqual(changed.generate(), expected)
        with self.assertRaisesRegex(ValueError, "differs"):
            changed.verify()

    def test_rejects_missing_and_ambiguous_evidence(self):
        with self.assertRaisesRegex(ValueError, "missing source tail-call evidence"):
            self.islands.generate()
        slots = sorted(self.islands.slots)
        self.islands.calls.update({slot: {name} for slot, name in zip(slots, self.names)})
        self.islands.calls[slots[0]].add("_sinf")
        with self.assertRaisesRegex(ValueError, "conflicting imported symbols"):
            self.islands.generate()
        self.islands.calls[slots[0]] = {"_sinf"}
        with self.assertRaisesRegex(ValueError, "ambiguous island"):
            self.islands.generate()


if __name__ == "__main__":
    unittest.main()
