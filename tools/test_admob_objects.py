"""Regression tests for Mach-O data and relocation evidence used in matching."""
from collections import Counter, defaultdict
from dataclasses import replace
import struct
from types import SimpleNamespace
import unittest

from linkmatch import Layout, Reference, Section
from admob_objects import add_constant_imports, place_initializers, string_initializers


class ConstantImportsTest(unittest.TestCase):
    def test_requires_a_local_pointer_to_a_unique_cfstring(self):
        const = SimpleNamespace(name="__const", segment="__DATA", addr=0, size=32)
        strings = SimpleNamespace(name="__cfstring", segment="__DATA", addr=32, size=32)
        ref = SimpleNamespace(targets={("__cfstring", "x"): {0x5000}})
        name = "_a"
        definitions = [(name, 0x1f, 1, 0, 0)]
        member = SimpleNamespace(by_name={"__const": const, "__cfstring": strings},
                                 sections=[const, strings], defined={0: [name]},
                                 read=lambda pos: 32, cfstring=lambda pos: "x",
                                 relocations={"__const": [(0, 0, 0x04000002, None)]})
        self.assertEqual(string_initializers(member, ref, definitions), {0: (name, 0x5000)})
        self.assertEqual(string_initializers(member, ref, [(name, 0xe, 1, 0, 0)]), {})
        for flags, desc in [(0x80000000, 0x04000002), (0, 0x0c000002), (0, 0x04000001)]:
            member.relocations["__const"] = [(0, flags, desc, None)]
            self.assertEqual(string_initializers(member, ref, definitions), {})
        member.relocations["__const"] = [(0, 0, 0x04000002, None)]
        member.defined[0].append("_alias")
        self.assertEqual(string_initializers(member, ref, definitions), {})
        member.defined[0].remove("_alias")
        ref.targets[("__cfstring", "x")].add(0x5010)
        self.assertEqual(string_initializers(member, ref, definitions), {})

    def test_requires_unique_adjacent_distinct_initializers(self):
        def place(entries, linked):
            return list(place_initializers(entries, linked, 0x1000))

        a, b = ("_a", 0x1234), ("_b", 0x5678)
        pair = struct.pack("<II", a[1], b[1])
        entries = {16: a, 20: b}
        self.assertEqual(place(entries, bytes(4) + pair), [("_a", 0x1004), ("_b", 0x1008)])
        for incomplete in ({16: a}, {16: a, 24: b}, {16: a, 20: ("_b", a[1])}):
            self.assertEqual(place(incomplete, pair + pair[:4] * 2), [])
        for ambiguous in (pair * 2, bytes(1) + pair, pair[:4] + bytes(4)):
            self.assertEqual(place(entries, ambiguous), [])

    def test_rejects_conflicting_names_and_slots(self):
        slots = {0x2000: 0x1000, 0x2004: 0x1004, 0x2008: 0x1004}

        def resolve(candidates, definitions, existing=None):
            targets = defaultdict(set, {key: set(value) for key, value in (existing or {}).items()})
            ref = SimpleNamespace(targets=targets, read=slots.__getitem__,
                                  pointers=lambda section: slots)
            add_constant_imports(ref, candidates, Counter(definitions))
            return dict(targets)

        single = [("_a", 0x1000)]
        key = ("__nl_symbol_ptr", "_a")
        self.assertEqual(resolve(single, ["_a"]), {key: {0x2000}})
        self.assertEqual(resolve(single, ["_a", "_a"]), {})
        self.assertEqual(resolve(single + [("_b", 0x1000)], ["_a", "_b"]), {})
        self.assertEqual(resolve(single + [("_a", 0x1004)], ["_a"]), {})
        self.assertEqual(resolve([("_a", 0x1004)], ["_a"]), {})
        self.assertEqual(resolve([("_a", 0x100c)], ["_a"]), {})
        for prior in ({"_a": {0x1004}}, {key: {0x2004}}, {("__nl_symbol_ptr", "_b"): {0x2000}}):
            self.assertEqual(resolve(single, ["_a"], prior), prior)



class LinkLayoutTest(unittest.TestCase):
    @staticmethod
    def layout(kind, *sections):
        """Build just the section data and symbol tables consumed by target()."""
        layout = kind.__new__(kind)
        layout.data = b""
        layout.sections = []
        for name, segment, address, data in sections:
            layout.sections.append(Section(name, segment, address, len(data), len(layout.data), 0, 0, 0, 0))
            layout.data += data
        layout.by_name = {s.name: s for s in layout.sections}
        layout.defined = defaultdict(list)
        layout.external = {}
        layout.relocations = defaultdict(list)
        layout.targets = defaultdict(set)
        layout.exception_records = {}
        return layout

    def test_weak_bind_annotation_is_not_part_of_symbol(self):
        ref = self.layout(Reference)
        ref.add_bound_symbols(
            "segment section address type addend dylib symbol\n"
            "__DATA __objc_classrefs 0x1010 pointer 0 AdSupport _OBJC_CLASS_$_ASIdentifierManager (weak_import)\n"
            "__DATA __nl_symbol_ptr 0x1020 pointer 0 Foundation _NSLocalizedDescriptionKey\n"
            "__DATA __const 0x1030 pointer 0 libSystem __NSConcreteGlobalBlock\n"
        )
        self.assertEqual(ref.targets, {
            ("__objc_classrefs", "_OBJC_CLASS_$_ASIdentifierManager"): {0x1010},
            ("__nl_symbol_ptr", "_NSLocalizedDescriptionKey"): {0x1020},
            ("global_block",): {0x1030},
        })

    def test_protocol_pointer_requires_matching_protocol_list_entry(self):
        ref = self.layout(Reference)
        ref.targets[("__objc_protorefs", "Delegate")] = {0x8000}
        for external in (False, True):
            with self.subTest(external=external):
                protocol = 0 if external else 0x200
                obj = self.layout(Layout,
                    ("__objc_protorefs", "__DATA", 0x100, struct.pack("<I", protocol)),
                    ("__objc_protolist", "__DATA", 0x104, struct.pack("<I", protocol)),
                    ("__data", "__DATA", 0x200, struct.pack("<II", 0, 0x208) + b"Delegate\0"))
                if external:
                    obj.external = {0x100: "l_OBJC_PROTOCOL_$_Delegate", 0x104: "l_OBJC_PROTOCOL_$_Delegate"}
                self.assertEqual(ref.target(obj, 0x100), 0x8000)
                if external:
                    obj.external[0x104] = "l_OBJC_PROTOCOL_$_Other"
                else:
                    obj.data = obj.data[:4] + bytes(4) + obj.data[8:]
                with self.assertRaisesRegex(ValueError, "unmapped Objective-C protocol"):
                    ref.target(obj, 0x100)

    def test_literal16_requires_one_full_aligned_text_constant(self):
        literal = bytes(range(16))
        obj = self.layout(Layout, ("__literal16", "__TEXT", 0x100, literal))
        ref = self.layout(Reference,
            ("__const", "__TEXT", 0x1000, bytes(4) + literal),
            ("__const", "__DATA", 0x2000, literal),
            ("__literal16", "__TEXT", 0x3000, b"x" + literal))
        self.assertEqual(ref.target(obj, 0x100), 0x1004)
        with self.assertRaisesRegex(ValueError, "partial"):
            ref.target(obj, 0x104)
        obj.by_name["__literal16"] = replace(obj.by_name["__literal16"], nreloc=1)
        with self.assertRaisesRegex(ValueError, "relocated"):
            ref.target(obj, 0x100)
        obj.by_name["__literal16"] = obj.sections[0]
        ref = self.layout(Reference, ("__const", "__TEXT", 0x1000, literal * 2))
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            ref.target(obj, 0x100)

    def test_typed_exception_record_relocates_and_checks_entire_table(self):
        table = "__gcc_except_tab"
        section = "__nl_symbol_ptr"
        pointer = "_OBJC_EHTYPE_$_NSException"
        field = 0x104
        target = 0x200
        raw = b"head" + struct.pack("<I", target - field) + b"tail"
        obj = self.layout(Layout, (table, "__TEXT", 0x100, raw), (section, "__DATA", target, bytes(4)))
        obj.external[target] = pointer
        obj.relocations[table] = [(field, 0xa2000004, target, (0xa1000000, field))]
        where = 0x1004
        relocated = b"head" + struct.pack("<I", 0x2000 - (where + 4)) + b"tail"
        ref = self.layout(Reference, (table, "__TEXT", 0x1000, bytes(4) + relocated))
        ref.targets[(section, pointer)] = {0x2000}
        self.assertEqual(ref.target(obj, 0x108), where + 8)
        ref.data = ref.data[:-1] + b"!"
        with self.assertRaisesRegex(ValueError, "exception tables"):
            ref.target(obj, 0x108)
        ref.data = bytes(4) + relocated
        obj.relocations[table] = [(field, 0xa2000004, target, (0xa1000000, field + 4))]
        with self.assertRaisesRegex(ValueError, "unsupported exception-table relocation"):
            ref.target(obj, 0x108)

    def test_repeated_exception_records_require_matching_owner_and_length(self):
        table = "__gcc_except_tab"
        record = b"\xff\xfe\xfd\x00\x01\x02\x00\x00"
        obj = self.layout(Layout, (table, "__TEXT", 0x100, record))
        obj.defined[0x100] = ["GCC_except_table3"]
        obj.defined[0x200] = ["-[Example load]"]
        ref = self.layout(Reference, (table, "__TEXT", 0x1000, record * 2))
        with self.assertRaisesRegex(ValueError, "ambiguous exception tables"):
            ref.target(obj, 0x100, 0x200)
        ref.exception_records["-[Example load]::LSDA"] = (0x1008, len(record))
        self.assertEqual(ref.target(obj, 0x100, 0x200), 0x1008)
        with self.assertRaisesRegex(ValueError, "ambiguous exception tables"):
            ref.target(obj, 0x100, 0x204)
        ref.exception_records["-[Example load]::LSDA"] = (0x1008, len(record) - 1)
        with self.assertRaisesRegex(ValueError, "record length"):
            ref.target(obj, 0x100, 0x200)


if __name__ == "__main__":
    unittest.main()
