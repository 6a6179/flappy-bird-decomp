"""Source-owned alignment, linker alignment and complete code-section assembly."""
import hashlib
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from arm_padding import CodePadding, encode_padding
from assembly import assemble_mixed, complete_text
from verify import Match


class PaddingTests(unittest.TestCase):
    def test_thumb_and_arm_encodings(self):
        self.assertEqual(encode_padding(True, 6, 2), bytes.fromhex('00bf c046 c046'))
        self.assertEqual(encode_padding(False, 8, 4), bytes.fromhex('00f020e3 0000a0e1'))
        for gap, assembler in [(5, 2), (6, 3), (2, 4)]:
            with self.subTest(gap=gap, assembler=assembler), self.assertRaises(ValueError):
                encode_padding(True, gap, assembler)

    def test_distinct_input_and_linker_fill_are_checked(self):
        first = Match('armv7', 0x1000, 2, Path('a.c'), '_a', ())
        second = first._replace(address=0x1008, symbol='_b', source=Path('b.c'))
        image = SimpleNamespace(text=SimpleNamespace(align=3), starts={0x1000: True, 0x1008: True},
                                ends={0x1000: 0x1008, 0x1008: 0x100a})
        raw = bytes.fromhex('7047 00bf 7047')
        obj = SimpleNamespace(symbols={'_a': SimpleNamespace(addr=0, description=8)},
                              text=SimpleNamespace(addr=0, size=len(raw)),
                              text_bytes=lambda a, n: raw[a:a+n])
        padding = CodePadding(image, {})
        padding.observe(first, obj, {0: 2, 4: 6})
        padding.rows[second.address] = second
        bodies = {0x1000: raw[:2], 0x1008: raw[4:]}
        image.text_bytes = lambda a, n: bytes.fromhex('00bf c046 c046')
        slots, count = padding.complete(bodies, set())
        self.assertEqual(count, 6)
        self.assertEqual(slots[0x1000], bytes.fromhex('7047 00bf c046 c046'))
        # A sequence of equally valid architectural no-ops is still the wrong layout.
        image.text_bytes = lambda a, n: bytes.fromhex('00bf 00bf 00bf')
        with self.assertRaisesRegex(ValueError, 'generated alignment differs'):
            padding.complete(bodies, set())

    def test_all_complete_slots_need_no_listing(self):
        body = bytes.fromhex('7047 00bf 7047')
        image = SimpleNamespace(arch='sample', text=SimpleNamespace(addr=0x1000, size=6),
                                starts={0x1000: True, 0x1004: True}, ends={0x1000: 0x1004, 0x1004: 0x1006})
        compiled = {0x1004: body[4:], 0x1000: body[:4]}
        with patch.dict('assembly.TEXT_SHA256', sample=hashlib.sha256(body).hexdigest()), \
                patch('assembly.gzip.open', side_effect=AssertionError('read archived listing')):
            self.assertEqual(assemble_mixed(image, compiled, None), body)
            with self.assertRaisesRegex(ValueError, 'missing'):
                complete_text(image, {0x1000: body[:4]})
            with self.assertRaisesRegex(ValueError, 'incomplete generated slot'):
                complete_text(image, {0x1000: body[:2], 0x1004: body[4:]})
            compiled[0x1004] = bytes(2)
            with self.assertRaisesRegex(ValueError, 'source-generated __text differs'):
                assemble_mixed(image, compiled, None)
