"""Check the C++ input-section boundary used to generate game alignment."""

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from linkmatch import link_function
from verify import ROOT, compile_source, find_tool, original_images, read_manifests


class GamePoolLayoutTest(unittest.TestCase):
    def test_both_pool_specializations_match_in_the_coalesced_section(self):
        clang = ROOT / ".toolchains/apple502/bin/clang"
        ipa = ROOT / "Flappy Bird v1.2.ipa"
        if not clang.is_file() or not ipa.is_file():
            self.skipTest("requires Apple Clang 5.0.2 and the reference IPA")
        fixture = ROOT / "tools/fixtures/game_pool_layout.cpp"
        signatures = {"_init_number_pool": "__Z15initialize_poolI14FloatingNumberEvP10SpritePooli",
                      "_init_sparkle_pool": "__Z15initialize_poolI14AnimatedSpriteEvP10SpritePooli"}
        rows = {(r.arch, r.symbol): r for r in read_manifests() if r.symbol in signatures}
        with TemporaryDirectory() as temp:
            for arch, original in original_images(ipa).items():
                row = rows[arch, "_init_number_pool"]._replace(
                    source=fixture, flags=("-fno-common", "-fwrapv", "-I", str(ROOT / "src")))
                obj, extents = compile_source(row, Path(temp) / f"{arch}.o", clang, find_tool("llvm-dwarfdump"))
                for name, signature in signatures.items():
                    with self.subTest(arch=arch, symbol=name):
                        symbol = obj.symbols[signature]
                        section = obj.sections[symbol.section - 1]
                        self.assertEqual((section.segment, section.name), ("__TEXT", "__textcoal_nt"))
                        if name == "_init_number_pool":
                            self.assertEqual(symbol.addr, section.addr)
                        length = extents[symbol.addr] - symbol.addr
                        address = rows[arch, name].address
                        self.assertEqual(rows[arch, name].length, length)
                        body = link_function(obj.data, original.data, symbol.addr, address, length)
                        self.assertEqual(body, original.text_bytes(address, length))


if __name__ == "__main__":
    unittest.main()
