"""Ensure linked registration checks catch changes which still permit a successful link."""
import copy
import struct
import unittest

from check_editable_admob import Method, RuntimeMetadata, differences
from verify import ROOT, original_images


class EditableAdMobMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ipa = ROOT / 'Flappy Bird v1.2.ipa'
        if not ipa.is_file():
            raise unittest.SkipTest('requires the original IPA')
        cls.image = original_images(ipa)['armv7']
        cls.original = RuntimeMetadata(cls.image.data)

    def replacement(self, address, value):
        data = bytearray(self.image.data)
        struct.pack_into('<I', data, self.original.layout.file_offset(address), value)
        return bytes(data)

    def test_duplicate_registered_class_is_rejected(self):
        layout = self.original.layout
        first, second, *_ = layout.pointers('__objc_classlist')
        with self.assertRaisesRegex(ValueError, 'duplicate entry in __objc_classlist'):
            RuntimeMetadata(self.replacement(second, layout.read(first)))

    def test_wrong_ivar_offset_and_method_shape_are_visible(self):
        layout = self.original.layout
        cls = self.original.classes['GADRequest']
        ro = self.original.ro(cls.address)
        ivars = layout.read(ro + 28)
        offset_cell = layout.read(ivars + 8)
        candidate = RuntimeMetadata(self.replacement(offset_cell, layout.read(offset_cell) + 4))
        self.assertTrue(any(line.startswith('GADRequest ivars:') for line in differences(self.original, candidate)))
        cls = candidate.classes['GADRequest']
        key = next(iter(cls.methods))
        cls.methods[key] = Method('v@:', cls.methods[key].imp)
        self.assertTrue(any(line.startswith('GADRequest methods:') for line in differences(self.original, candidate)))

    def test_dangling_method_implementation_is_rejected(self):
        layout = self.original.layout
        ro = self.original.ro(self.original.classes['GADRequest'].address)
        methods = layout.read(ro + 20)
        with self.assertRaisesRegex(ValueError, 'does not point to a matching function entry'):
            RuntimeMetadata(self.replacement(methods + 16, 0))

    def test_missing_foundation_category_is_detected(self):
        edited = copy.copy(self.original)
        edited.categories = dict(edited.categories)
        del edited.categories['NSError', 'GADInternalErrorAdditions']
        self.assertTrue(any('missing' in line and 'GADInternalErrorAdditions' in line
                            for line in differences(self.original, edited)))
