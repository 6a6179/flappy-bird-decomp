#!/usr/bin/env python3
"""Compare registered Objective-C metadata in the two linked iOS applications."""
import argparse
from dataclasses import dataclass, field
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zipfile

from linkmatch import Layout
from objc_protocols import protocol_definitions, protocol_names
from verify import ARCHES, CPU_ARM, EXECUTABLE, ROOT, Image, original_images


def candidate_images(ipa):
    with zipfile.ZipFile(ipa) as archive:
        binary = archive.read(EXECUTABLE)
    magic, count = struct.unpack_from('>II', binary)
    if magic != 0xcafebabe:
        raise ValueError('expected a universal editable executable')
    images = {}
    for i in range(count):
        cpu, subtype, offset, size, _ = struct.unpack_from('>5I', binary, 8 + i * 20)
        arch = ARCHES.get(subtype & 0xffffff)
        if cpu != CPU_ARM or arch is None:
            continue
        if arch in images or offset + size > len(binary):
            raise ValueError(f'invalid or repeated {arch} slice')
        image = Image(binary[offset:offset + size])
        if image.arch != arch or image.filetype != 2 or not image.starts:
            raise ValueError(f'invalid {arch} executable')
        images[arch] = image
    if set(images) != set(ARCHES.values()):
        raise ValueError('editable IPA must contain both ARMv7 and ARMv7s')
    return images


@dataclass(frozen=True)
class Method:
    encoding: str
    imp: int = field(compare=False)


@dataclass(frozen=True)
class Ivar:
    encoding: str
    offset: int
    alignment: int
    size: int


@dataclass
class ClassInfo:
    address: int = field(compare=False)
    superclass: str
    instance_start: int
    instance_size: int
    flags: int
    metaclass_flags: int
    metaclass_instance_start: int
    metaclass_instance_size: int
    strong_layout: bytes | None
    weak_layout: bytes | None
    ivars: dict
    protocols: set
    properties: dict
    methods: dict


@dataclass
class Category:
    protocols: set
    properties: dict
    methods: dict


def sdk_name(name):
    return name.startswith(('GAD', 'DFP'))


def insert_unique(mapping, key, value, context):
    if key in mapping:
        raise ValueError(f'{context}: duplicate {key!r}')
    mapping[key] = value


class RuntimeMetadata:
    """Read linked 32-bit Objective-C class, metaclass, category and protocol lists."""
    def __init__(self, data):
        self.layout = layout = Layout(data)
        image = Image(data)
        self.bindings = {}
        with tempfile.NamedTemporaryFile() as thin:
            thin.write(data)
            thin.flush()
            output = subprocess.check_output(['xcrun', 'llvm-objdump', '--macho', '--bind', thin.name], text=True)
        for line in output.splitlines():
            fields = line.split()
            if len(fields) >= 7 and fields[2].startswith('0x') and fields[3] == 'pointer':
                self.bindings[int(fields[2], 16)] = fields[6]
        self.classes = {}
        self.categories = {}
        self.protocols = protocol_definitions(layout)
        registered = [layout.read(slot) for slot in layout.pointers('__objc_classlist')]
        classes = {cls: self.ro(cls) for cls in registered}
        if len(classes) != len(registered):
            raise ValueError('duplicate entry in __objc_classlist')
        owners = {cls: layout.string(layout.read(ro + 16)) for cls, ro in classes.items()}
        meta_owners = {layout.read(cls): name for cls, name in owners.items()}
        nonlazy = ([layout.read(slot) for slot in layout.pointers('__objc_nlclslist')]
                   if '__objc_nlclslist' in layout.by_name else [])
        if len(nonlazy) != len(set(nonlazy)) or set(nonlazy) - owners.keys():
            raise ValueError('invalid non-lazy class registration')
        self.eager_classes = {owners[cls] for cls in nonlazy}
        for cls, ro in classes.items():
            name = owners[cls]
            meta = self.ro(layout.read(cls))
            if layout.string(layout.read(meta + 16)) != name or not layout.read(meta) & 1:
                raise ValueError(f'{name}: invalid metaclass')
            superclass = self.class_name(owners, cls + 4)
            if superclass and self.class_name(meta_owners, layout.read(cls) + 4, metaclass=True) != superclass:
                raise ValueError(f'{name}: superclass and metaclass superclass disagree')
            methods = self.method_list(layout.read(ro + 20), '-', name, image)
            methods.update(self.method_list(layout.read(meta + 20), '+', name, image))
            info = ClassInfo(cls, superclass, layout.read(ro + 4), layout.read(ro + 8),
                             layout.read(ro), layout.read(meta), layout.read(meta + 4), layout.read(meta + 8),
                             self.ivar_layout(layout.read(ro + 12)),
                             self.ivar_layout(layout.read(ro + 32)), self.ivars(layout.read(ro + 28), name),
                             set(protocol_names(layout, layout.read(ro + 24))),
                             self.properties(layout.read(ro + 36), name), methods)
            insert_unique(self.classes, name, info, 'registered classes')
        category_names = {}
        category_slots = layout.pointers('__objc_catlist') if '__objc_catlist' in layout.by_name else ()
        for slot in category_slots:
            cat = layout.read(slot)
            name = layout.string(layout.read(cat))
            cls = self.class_name(owners, cat + 4)
            if not cls:
                raise ValueError(f'{name}: category has no target class')
            label = f'{cls}({name})'
            category_names[cat] = (cls, name)
            methods = self.method_list(layout.read(cat + 8), '-', label, image)
            methods.update(self.method_list(layout.read(cat + 12), '+', label, image))
            category = Category(set(protocol_names(layout, layout.read(cat + 16))),
                                self.properties(layout.read(cat + 20), label), methods)
            insert_unique(self.categories, (cls, name), category, 'registered categories')
            if cls in self.classes:
                info = self.classes[cls]
                for selector, method in category.methods.items():
                    insert_unique(info.methods, selector, method, label)
                for prop, attributes in category.properties.items():
                    insert_unique(info.properties, prop, attributes, label)
                info.protocols.update(category.protocols)
        nonlazy = ([layout.read(slot) for slot in layout.pointers('__objc_nlcatlist')]
                   if '__objc_nlcatlist' in layout.by_name else [])
        if len(nonlazy) != len(set(nonlazy)) or set(nonlazy) - category_names.keys():
            raise ValueError('invalid non-lazy category registration')
        self.eager_categories = {category_names[cat] for cat in nonlazy}

    def ro(self, cls):
        return self.layout.read(cls + 16) & ~3

    def class_name(self, owners, slot, metaclass=False):
        cls = self.layout.read(slot)
        if cls:
            if cls not in owners:
                raise ValueError(f'unregistered class pointer {cls:#x} at {slot:#x}')
            return owners[cls]
        external = self.bindings.get(slot)
        if external:
            prefix = '_OBJC_METACLASS_$_' if metaclass else '_OBJC_CLASS_$_'
            if not external.startswith(prefix):
                raise ValueError(f'unexpected class binding {external} at {slot:#x}')
            return external[len(prefix):]
        return ''  # Root classes have a null superclass.

    def ivar_layout(self, ptr):
        if not ptr:
            return None
        off = self.layout.file_offset(ptr)
        return self.layout.data[off:self.layout.data.index(b'\0', off)]

    def list_entries(self, ptr, stride, label):
        if not ptr:
            return ()
        layout = self.layout
        # The historical 32-bit runtime uses absolute method pointers and
        # fixed-width ivar and property records.
        if layout.read(ptr) & ~3 != stride:
            raise ValueError(f'{label}: unsupported entry size at {ptr:#x}')
        count = layout.read(ptr + 4)
        end = ptr + 8 + count * stride
        section = layout.section_at(ptr)
        if end > section.addr + section.size:
            raise ValueError(f'{label}: list extends outside {section.name}')
        return range(ptr + 8, end, stride)

    def method_list(self, ptr, sign, owner, image):
        methods = {}
        layout = self.layout
        for rec in self.list_entries(ptr, 12, owner):
            name = layout.string(layout.read(rec))
            encoding = layout.string(layout.read(rec + 4))
            imp = layout.read(rec + 8)
            if image.starts.get(imp & ~1) != bool(imp & 1):
                raise ValueError(f'{sign}[{owner} {name}]: IMP {imp:#x} does not point to a matching function entry')
            insert_unique(methods, (sign, name), Method(encoding, imp), owner)
        return methods

    def ivars(self, ptr, owner):
        ivars = {}
        layout = self.layout
        for rec in self.list_entries(ptr, 20, owner):
            offset = layout.read(layout.read(rec))
            name = layout.string(layout.read(rec + 4))
            encoding = layout.string(layout.read(rec + 8))
            insert_unique(ivars, name, Ivar(encoding, offset, layout.read(rec + 12), layout.read(rec + 16)), owner)
        return ivars

    def properties(self, ptr, owner):
        result = {}
        for rec in self.list_entries(ptr, 8, owner):
            name = self.layout.string(self.layout.read(rec))
            attributes = self.layout.string(self.layout.read(rec + 4))
            insert_unique(result, name, attributes, owner)
        return result


def compare_items(context, expected, actual):
    """Report missing, extra and changed declarations with actionable names."""
    for key in sorted(expected.keys() - actual.keys()):
        yield f'{context}: missing {key}'
    for key in sorted(actual.keys() - expected.keys()):
        yield f'{context}: unexpected {key}'
    for key in sorted(expected.keys() & actual.keys()):
        if expected[key] != actual[key]:
            if isinstance(expected[key], Method):
                before, after = expected[key].encoding, actual[key].encoding
            else:
                before, after = expected[key], actual[key]
            yield f'{context}: {key}: expected {before!r}, got {after!r}'


def compare_members(context, expected, actual):
    for name in ('protocols', 'properties', 'methods'):
        left, right = getattr(expected, name), getattr(actual, name)
        if name == 'protocols':
            left, right = dict.fromkeys(left), dict.fromkeys(right)
        yield from compare_items(f'{context} {name}', left, right)


def differences(reference, editable):
    expected = set(reference.classes)
    actual = set(editable.classes)
    yield from compare_items('registered classes', dict.fromkeys(expected), dict.fromkeys(actual))
    yield from compare_items('non-lazy class registrations',
                             dict.fromkeys(reference.eager_classes), dict.fromkeys(editable.eager_classes))
    for name in sorted(expected & actual):
        original, candidate = reference.classes[name], editable.classes[name]
        for key in ('superclass', 'instance_start', 'instance_size', 'flags', 'metaclass_flags',
                    'metaclass_instance_start', 'metaclass_instance_size', 'strong_layout', 'weak_layout'):
            a, b = getattr(original, key), getattr(candidate, key)
            if a != b:
                yield f'{name} {key}: expected {a!r}, got {b!r}'
        yield from compare_items(f'{name} ivars', original.ivars, candidate.ivars)
        yield from compare_members(name, original, candidate)

    yield from compare_items('registered categories', dict.fromkeys(reference.categories), dict.fromkeys(editable.categories))
    yield from compare_items('non-lazy category registrations',
                             dict.fromkeys(reference.eager_categories), dict.fromkeys(editable.eager_categories))
    for cls, name in sorted(reference.categories.keys() & editable.categories.keys()):
        yield from compare_members(f'{cls}({name})', reference.categories[cls, name], editable.categories[cls, name])

    yield from compare_items('registered protocols', dict.fromkeys(reference.protocols), dict.fromkeys(editable.protocols))
    for name in sorted(reference.protocols.keys() & editable.protocols.keys()):
        original, candidate = reference.protocols[name], editable.protocols[name]
        for key in ('inherited', 'methods', 'properties'):
            left, right = getattr(original, key), getattr(candidate, key)
            yield from compare_items(f'protocol {name} {key}', dict.fromkeys(left), dict.fromkeys(right))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ipa', type=Path, default=ROOT / 'Flappy Bird v1.2.ipa', help='pinned original IPA')
    parser.add_argument('--candidate-ipa', type=Path, default=ROOT / 'build' / 'Flappy Bird editable.ipa')
    args = parser.parse_args()
    originals = original_images(args.ipa)
    candidates = candidate_images(args.candidate_ipa)
    failed = False
    for arch, image in originals.items():
        ref = RuntimeMetadata(image.data)
        candidate = RuntimeMetadata(candidates[arch].data)
        diffs = list(differences(ref, candidate))
        if diffs:
            failed = True
            print(f'{arch}: {len(diffs)} editable Objective-C metadata differences', file=sys.stderr)
            for diff in diffs:
                print(f'  {diff}', file=sys.stderr)
        else:
            sdk = [info for name, info in ref.classes.items() if sdk_name(name)]
            print(f'{arch}: matched {len(ref.classes)} registered classes, {len(ref.protocols)} protocols and '
                  f'{len(ref.categories)} categories. The {len(sdk)} AdMob classes implement '
                  f'{sum(len(c.methods) for c in sdk)} selectors and declare {sum(len(c.ivars) for c in sdk)} '
                  f'ivars and {sum(len(c.properties) for c in sdk)} properties.')
    return int(failed)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, struct.error, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        sys.exit(f'check_editable_admob: {error}')
