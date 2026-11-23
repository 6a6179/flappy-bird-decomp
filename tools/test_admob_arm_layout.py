import struct
import unittest

from admob_arm_layout import ArmLayout, LiteralLoad
from admob_fragment_pair import PairMove
from admob_inline_dispatch import branch


def words(*values):
    return struct.pack(f"<{len(values)}I", *values)


class ArmLayoutTests(unittest.TestCase):
    def test_expansion_uses_compiler_pool_and_maps_conditional_branch(self):
        # BEQ 12; LDR r2,[PC,#4] -> pool at 16; LDR r3,[PC,#0]; BX lr; pool.
        body = words(0x0a000001, 0xe59f2004, 0xe59f3000, 0xe12fff1e, 0xebffffff)
        layout = ArmLayout(len(body), [LiteralLoad(4)])
        emitted = layout.render(0x1000, body, set(), {16})[0x1000]
        expected = words(0x0a000004, 0xe59f2004, 0xe79f2002, 0xea000000, 12,
                         0xe59f3000, 0xe12fff1e, 0xebffffff)
        self.assertEqual(emitted, expected)
        changed = body[:-4] + words(0x42c80000)
        self.assertEqual(layout.render(0x1000, changed, set(), {16})[0x1000],
                         expected[:-4] + words(0x42c80000))

    def test_mixed_expansion_and_contraction_retarget_branches_and_data(self):
        # A literal load, two outlined arithmetic instructions, a backwards BNE
        # and a second load referencing the same first pool word.
        body = words(0x12345678, 0xe51f000c, 0xe24dd010, 0xe20110ff,
                     0x1afffffb, 0xe51f201c, 0xe12fff1e)
        pair = PairMove(8, 0x2000, 0, 0x3000)
        layout = ArmLayout(len(body), [pair, LiteralLoad(4)])
        placed = layout.render(0x1000, body, set(), {0})
        self.assertEqual(layout.map_offset(16), 24)
        self.assertEqual(placed[0x1000], words(0x12345678, 0xe59f0004, 0xe79f0000,
                                               0xea000000, 0xfffffff0, branch(0x1014, 0x2000)))
        self.assertEqual(placed[0x1018], words(0x1afffff9, 0xe51f2024, 0xe12fff1e))
        self.assertEqual(placed[0x2000][:8], body[8:16])

    def test_external_branch_relocations_are_already_at_their_final_pc(self):
        body = words(0xe59f0004, 0xeb000100, 0xe12fff1e, 6)
        layout = ArmLayout(len(body), [LiteralLoad(0)])
        emitted = layout.render(0x1000, body, {4}, {12})[0x1000]
        self.assertEqual(emitted[16:20], body[4:8])

    def test_refuses_invalid_offsets_pool_relocations_and_interiors(self):
        body = words(0xe59f0000, 0xe12fff1e, 0xe0000001)
        layout = ArmLayout(len(body), [LiteralLoad(0)])
        for relocations, pool in [({0}, {8}), (set(), set()), (set(), {0, 8})]:
            with self.subTest(relocations=relocations, pool=pool), self.assertRaises(ValueError):
                layout.render(0x1000, body, relocations, pool)
        for sites in [[LiteralLoad(-4)], [LiteralLoad(2)], [LiteralLoad(12)],
                      [LiteralLoad(0), LiteralLoad(0)]]:
            with self.subTest(sites=sites), self.assertRaises(ValueError):
                ArmLayout(len(body), sites)
        pair = PairMove(4, 0x2000, 0, 0x3000)
        layout = ArmLayout(16, [pair])
        with self.assertRaises(ValueError):
            layout.map_offset(8)
        with self.assertRaises(ValueError):
            layout.render(0x1000, words(0xea000000, 0xe24dd010, 0xe20110ff, 0xe12fff1e),
                          set(), set())

    def test_refuses_conditional_or_control_flow_literal_rewrite(self):
        for opcode in [0x059f2000, 0xe59ff000, 0xe28f2000]:
            with self.subTest(opcode=opcode), self.assertRaises(ValueError):
                ArmLayout(12, [LiteralLoad(0)]).render(0x1000, words(opcode, 0xe12fff1e, 0),
                                                       set(), {8})


if __name__ == "__main__":
    unittest.main()
