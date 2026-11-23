import struct
import unittest

from admob_inline_dispatch import branch, InlineDispatch


class InlineDispatchTests(unittest.TestCase):
    def test_either_arm_reaches_the_compiler_instruction(self):
        site, stub, alternate = 0x1008, 0x2000, 0x2800
        for selector, live, dead in [(0, 5, 8), (12, 8, 5)]:
            move = InlineDispatch.parse(f"dispatch:8:{stub}:{selector}:{alternate}")
            main, out = move.emit((0xe24dd020,), site, site + 40)
            words = struct.unpack("<10I", main)
            self.assertEqual(words[1], 0xe3a03000 | selector)
            self.assertEqual(words[live], branch(site + 4 * live, stub))
            self.assertEqual(words[dead], branch(site + 4 * dead, alternate))
            self.assertEqual(struct.unpack("<2I", out),
                             (0xe24dd020, branch(stub + 4, site + 40)))
            self.assertNotEqual(move.emit((0xe24dd024,), site, site + 40)[1], out)

    def test_nested_stub_preserves_the_instruction_and_real_continuation(self):
        move = InlineDispatch.parse("dispatch:8:0x2000:12:0x2800:0:0x2900")
        site, resume, stub = 0x1008, 0x1030, move.stub
        main, out = move.emit((0xe24dd024,), site, resume)
        self.assertEqual(len(main), 40)
        words = struct.unpack("<11I", out)
        self.assertEqual(words[0], 0xe24dd024)
        self.assertEqual(words[6], branch(stub + 24, resume))
        self.assertEqual(words[9], branch(stub + 36, 0x2900))
        with self.assertRaises(ValueError):
            InlineDispatch.parse("dispatch:8:0x2000:12:0x2800:0")

    def test_rejects_invalid_layout_and_pc_dependent_displacement(self):
        for instruction, resume, selector in [(0xe24dd020, 0x1034, 0),
                                               (0xe24dd020, 0x1030, 8),
                                               (0xe24fd020, 0x1030, 0)]:
            with self.assertRaises(ValueError):
                InlineDispatch(8, 0x2000, selector, 0x2800).emit((instruction,), 0x1008, resume)


if __name__ == "__main__":
    unittest.main()
