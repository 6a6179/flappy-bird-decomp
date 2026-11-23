"""32-bit linked Objective-C protocol metadata and corruption checks."""

import struct
import unittest

from linkmatch import Layout, Section
from objc_protocols import ProtocolMethod, ProtocolProperty, protocol_definitions, protocol_names


class ProtocolFixture:
    def __init__(self):
        self.records = bytearray()
        self.strings = bytearray()

    def string(self, value):
        address = 0x3000 + len(self.strings)
        self.strings.extend(value.encode() + b"\0")
        return address

    def words(self, *values):
        address = 0x2000 + len(self.records)
        self.records.extend(struct.pack(f"<{len(values)}I", *values))
        return address

    def record(self, name, *, inherited=0, methods=(0, 0, 0, 0), properties=0,
               extended=0, size=44, class_properties=0):
        data = [0, self.string(name), inherited, *methods, properties, size, 0,
                extended, 0, class_properties]
        return self.words(*data[:size // 4])

    def image(self, *entries):
        layout = object.__new__(Layout)
        data = bytearray(4)
        layout.sections = []
        for name, address, content in [
                ("__objc_protolist", 0x1000, struct.pack(f"<{len(entries)}I", *entries)),
                ("__objc_const", 0x2000, self.records),
                ("__objc_methname", 0x3000, self.strings)]:
            layout.sections.append(Section(name, "__DATA", address, len(content), len(data), 0, 0, 0, 0))
            data.extend(content)
        layout.data = bytes(data)
        layout.by_name = {sec.name: sec for sec in layout.sections}
        return layout


class ProtocolDecodingTest(unittest.TestCase):
    def test_extended_types_follow_method_lists_before_sorting(self):
        f = ProtocolFixture()
        parent = f.record("Base", size=40)
        inherited = f.words(1, parent)
        entries = [("z:", "v@:@", 'v@:@"NSString"'), ("a", "v@:", "v@:"),
                   ("same", "I@:", "I@:"), ("opt", "@@:", '@"Object"@:'),
                   ("same", "B@:", "B@:")]
        def methods(*indices):
            rows = [word for i in indices for word in (f.string(entries[i][0]), f.string(entries[i][1]), 0)]
            return f.words(12, len(indices), *rows)
        lists = methods(0, 1), methods(2), methods(3, 4), 0
        extended = f.words(*(f.string(ext) for _, _, ext in entries))
        instance_property = f.words(8, 1, f.string("value"), f.string("Ti,R"))
        class_property = f.words(8, 1, f.string("value"), f.string("T@,R"))
        child = f.record("Child", inherited=inherited, methods=lists, properties=instance_property,
                         extended=extended, size=52, class_properties=class_property)
        image = f.image(parent, child)
        self.assertEqual(protocol_names(image, inherited), ("Base",))
        self.assertEqual(protocol_names(image, 0), ())
        result = protocol_definitions(image)["Child"]
        self.assertEqual(result.inherited, ("Base",))
        self.assertEqual(set(result.methods), {
            ProtocolMethod("required", "instance", *entries[0]), ProtocolMethod("required", "instance", *entries[1]),
            ProtocolMethod("required", "class", *entries[2]), ProtocolMethod("optional", "instance", *entries[3]),
            ProtocolMethod("optional", "instance", *entries[4])})
        self.assertEqual(result.properties, (ProtocolProperty("class", "value", "T@,R"),
                                             ProtocolProperty("instance", "value", "Ti,R")))

    def test_accepts_equal_definitions_and_rejects_conflicts(self):
        f = ProtocolFixture()
        first, second = f.record("Repeated"), f.record("Repeated")
        inherited = f.words(1, first)
        other = f.record("Repeated", inherited=inherited)
        self.assertEqual(set(protocol_definitions(f.image(first, second))), {"Repeated"})
        with self.assertRaisesRegex(ValueError, "conflicting definitions"):
            protocol_definitions(f.image(first, other))
        duplicated_list = f.words(2, first, second)
        with self.assertRaisesRegex(ValueError, "duplicate protocol adoption"):
            protocol_names(f.image(first, second), duplicated_list)

    def test_rejects_duplicate_selectors_and_properties(self):
        f = ProtocolFixture()
        sel, typ = f.string("result"), f.string("@@:")
        method = f.words(12, 1, sel, typ, 0)
        with self.assertRaisesRegex(ValueError, "duplicate instance method"):
            protocol_definitions(f.image(f.record("Repeated", methods=(method, 0, method, 0))))
        properties = f.words(8, 2, sel, typ, sel, typ)
        with self.assertRaisesRegex(ValueError, "duplicate instance property"):
            protocol_definitions(f.image(f.record("Repeated", properties=properties)))

    def test_optional_tables_and_malformed_pointers(self):
        f = ProtocolFixture()
        sel, typ = f.string("result"), f.string("@@:")
        method = f.words(12, 1, sel, typ, 0)
        old = f.record("Old", methods=(method, 0, 0, 0), size=40)
        self.assertIsNone(protocol_definitions(f.image(old))["Old"].methods[0].extended)
        for entry in (0, old + 1, 0xffffffff):
            with self.subTest(entry=entry), self.assertRaises(ValueError):
                protocol_definitions(f.image(entry))
        for bad_list in [f.words(12, 0xffffffff), f.words(8, 0)]:
            with self.subTest(bad_list=bad_list), self.assertRaises(ValueError):
                protocol_definitions(f.image(f.record("Bad", methods=(bad_list, 0, 0, 0))))
        null_type = f.words(0)
        bad = f.record("Bad", methods=(method, 0, 0, 0), extended=null_type)
        with self.assertRaises(ValueError):
            protocol_definitions(f.image(bad))
        string_record = f.record("Truncated")
        f.strings[-1] = 65
        with self.assertRaisesRegex(ValueError, "unterminated"):
            protocol_definitions(f.image(string_record))


if __name__ == "__main__":
    unittest.main()
