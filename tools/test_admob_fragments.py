import struct
import unittest
from types import SimpleNamespace

from admob_fragments import branch, Move, outline, stub_words
from admob_fragment_pair import PairMove


class OutlinedCodeTests(unittest.TestCase):
    def setUp(self):
        self.base = 0x1000
        self.stub = 0x2000
        # A frame, stack reservation, then return. The reservation is moved.
        self.body = struct.pack("<4I", 0xe92d4080, 0xe1a0700d, 0xe24dd010, 0xe8bd8080)

    def image(self, size):
        ends = {self.base: self.base + 12, self.base + 12: self.base + 16,
                self.stub: self.stub + size}
        return SimpleNamespace(starts=dict.fromkeys(ends, False), ends=ends)

    def test_parts_only_use_input_body_and_layout(self):
        move = Move(8, self.stub)
        parts = outline(self.image(8), self.base, self.body, [move], set())
        self.assertEqual(set(parts), {self.base, self.base + 12, self.stub})
        self.assertEqual(parts[self.base][:8], self.body[:8])
        self.assertEqual(parts[self.base + 12], self.body[12:])
        self.assertEqual(parts[self.stub][:4], self.body[8:12])
        self.assertEqual(struct.unpack("<I", parts[self.base][8:])[0], 0xea0003fc)
        self.assertEqual(struct.unpack("<I", parts[self.stub][4:])[0], 0xeafffc00)
        edited = self.body[:8] + struct.pack("<I", 0xe24dd020) + self.body[12:]
        self.assertNotEqual(outline(self.image(8), self.base, edited, [move], set()), parts)

    def test_dispatch_resumes_only_at_original_continuation(self):
        for selector in (0, 12):
            alternate = 0x1800
            move = Move(8, self.stub, selector, alternate)
            code = outline(self.image(44), self.base, self.body, [move], set())[self.stub]
            words = struct.unpack("<11I", code)
            self.assertEqual(words[2], 0xe3a03000 | selector)
            live, unused = (6, 9) if selector == 0 else (9, 6)
            self.assertEqual(words[live], branch(self.stub + 4 * live, self.base + 12))
            self.assertEqual(words[unused], branch(self.stub + 4 * unused, alternate))
            self.assertEqual(words[0], 0xe24dd010)

    def test_displaced_pair_preserves_both_compiler_words(self):
        first, second = 0xe24dd010, 0xe2000001
        move = PairMove.parse("pair:8:0x2000:0:0x2040")
        main, stub = move.emit((first, second), 0x1008, 0x100c)
        self.assertEqual(struct.unpack("<I", main)[0], branch(0x1008, 0x2000))
        words = struct.unpack("<12I", stub)
        self.assertEqual(words[:2], (first, second))
        self.assertEqual(words[7], branch(0x201c, 0x100c))
        self.assertEqual(words[10], branch(0x2028, 0x2040))
        with self.assertRaises(ValueError):
            move.emit((first, 0xe12fff1e), 0x1008, 0x100c)
        with self.assertRaises(ValueError):
            move.emit((first, second), 0x1008, 0x1010)

    def test_rejects_relocations_position_dependent_words_and_bad_extents(self):
        move = Move(8, self.stub)
        with self.assertRaises(ValueError):
            outline(self.image(8), self.base, self.body, [move], {8})
        with self.assertRaises(ValueError):
            outline(self.image(12), self.base, self.body, [move], set())
        with self.assertRaises(ValueError):
            outline(self.image(8), self.base, self.body, [move, move], set())
        for insn in [0xe24fd004, 0xe08f4003, 0xe12fff1e, 0xe1a0f00e]:
            with self.subTest(insn=hex(insn)), self.assertRaises(ValueError):
                outline(self.image(8), self.base, self.body[:8] + struct.pack("<I", insn) + self.body[12:],
                        [move], set())
        with self.assertRaises(ValueError):
            stub_words(Move(8, self.stub, 8, self.stub), 0xe24dd010, self.base + 12)


if __name__ == "__main__":
    unittest.main()
