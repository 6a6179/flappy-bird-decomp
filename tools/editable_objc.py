"""Reunite split, source-compiled Objective-C implementations for the editable app.

Apple Clang 5 emits local method lists containing selector, type and implementation
triples. Keep those triples with their original code and strings, and attach a
single list per class to the canonical class_ro_t. Combining compiler assembly
before assembling lets the original PC-relative ivar loads use the canonical,
runtime-adjustable offset cell. No linked reference image is an input.
"""
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import re


SYMBOL = r'(?:"(?:\\.|[^"\\])*"|[a-zA-Z_.$][\w.$]*)'
TOKEN = re.compile(SYMBOL)
LABEL = re.compile(r'^(' + SYMBOL + r'):\s*(?:@.*)?$')
LONG = re.compile(r'^\s*\.long\s+(' + SYMBOL + r'|-?(?:0x[\da-fA-F]+|\d+))\s*(?:@.*)?$')
STRING = re.compile(r'^\s*\.asciz\s+("(?:\\.|[^"\\])*")\s*(?:@.*)?$')
DECLARATION = re.compile(r'^\s*\.(globl|private_extern|weak_definition|no_dead_strip)\s+(' + SYMBOL + r')')
DEFINITION = re.compile(r'^(?:\s*\.(?:set|lcomm|comm)\s+|\s*\.zerofill\s+[^,]+,[^,]+,\s*)(' + SYMBOL + r')')
ASSIGNMENT = re.compile(r'^(' + SYMBOL + r')\s*=')
CLASS = '_OBJC_CLASS_$_'
PROTO = re.compile(r'l_OBJC_(?:LABEL_PROTOCOL|PROTOCOL_REFERENCE|PROTOCOL)_\$_\w+$')
RO = {'-': 'l_OBJC_CLASS_RO_$_', '+': 'l_OBJC_METACLASS_RO_$_'}
DATA = re.compile(r'^\s*\.(?:long|short|byte|quad|space|zero|ascii|asciz)\b')


@dataclass(frozen=True)
class Method:
    unit: object
    sign: str
    cls: str
    selector: str
    fields: tuple

    @property
    def identity(self):
        return f'{self.sign}[{self.cls} {self.selector}]'


class Unit:
    def __init__(self, source, path, ordinal):
        self.source = Path(source)
        self.lines = Path(path).read_text().splitlines()
        self.ordinal = ordinal
        self.labels = {}
        self.definitions = set()
        self.globals = set()
        self.weak = set()
        self.omit = set()
        self.renames = {}
        self.extra = []
        self.declarations = defaultdict(list)
        for i, line in enumerate(self.lines):
            label = LABEL.match(line)
            if label:
                self.labels[label[1]] = i
                self.definitions.add(label[1])
            other = DEFINITION.match(line) or ASSIGNMENT.match(line)
            if other:
                self.definitions.add(other[1])
            dec = DECLARATION.match(line)
            if dec:
                self.declarations[dec[2]].append(i)
                if dec[1] in ('globl', 'private_extern'):
                    self.globals.add(dec[2])
                if dec[1] == 'weak_definition':
                    self.weak.add(dec[2])
        self.classes = {sym[len(CLASS):] for sym in self.labels if sym.startswith(CLASS)}

    def data(self, label):
        start = self.labels[label] + 1
        stop = start
        while stop < len(self.lines) and DATA.match(self.lines[stop]):
            stop += 1
        return range(start, stop)

    def longs(self, label):
        words = []
        for i in self.data(label):
            m = LONG.match(self.lines[i])
            if not m:
                raise ValueError(f'{self.source}: unexpected field in {label}: {self.lines[i]}')
            words.append(m[1])
        return words

    def remove(self, label):
        self.omit.add(self.labels[label])
        self.omit.update(self.data(label))
        self.omit.update(self.declarations[label])

    def methods(self, cls, sign):
        ro = RO[sign] + cls
        words = self.longs(ro)
        if len(words) != 10:
            raise ValueError(f'{self.source}: unknown 32-bit Objective-C class layout for {cls}')
        label = words[5]
        if label == '0':
            return
        stride, count, *fields = self.longs(label)
        if int(stride, 0) != 12 or len(fields) != 3 * int(count, 0):
            raise ValueError(f'{self.source}: invalid Objective-C method list {label}')
        for i in range(0, len(fields), 3):
            name, typ, imp = fields[i:i + 3]
            name_lines = self.data(name)
            if len(name_lines) != 1 or typ not in self.labels or imp not in self.labels:
                raise ValueError(f'{self.source}: incomplete Objective-C method entry at {label}')
            spelling = STRING.match(self.lines[name_lines.start])
            if not spelling:
                raise ValueError(f'{self.source}: missing selector string for {imp}')
            selector = spelling[1][1:-1]
            if imp != f'"{sign}[{cls} {selector}]"':
                raise ValueError(f'{self.source}: unexpected IMP {imp} for {selector}')
            yield Method(self, sign, cls, selector, (name, typ, imp))

    def remove_class(self, cls):
        records = {CLASS + cls, '_OBJC_METACLASS_$_' + cls}
        for prefix in RO.values():
            ro = prefix + cls
            fields = self.longs(ro)
            records.add(ro)
            # The method, protocol, ivar and property lists are class-owned.
            records.update(ref for ref in (fields[5], fields[6], fields[7], fields[9])
                           if ref != '0')
        records.update(s for s in self.labels if s.startswith('_OBJC_IVAR_$_' + cls + '.'))
        for record in records:
            self.remove(record)
        for name in ('L_OBJC_LABEL_CLASS_$', 'L_OBJC_LABEL_NONLAZY_CLASS_$'):
            if name in self.labels:
                for i in self.data(name):
                    if LONG.match(self.lines[i])[1] == CLASS + cls:
                        self.omit.add(i)

    def namespace(self, keep):
        # Keeping Darwin L labels temporary preserves section/subsection boundaries.
        for i, name in enumerate(sorted(self.definitions - self.globals - keep)):
            prefix = 'L' if name.startswith('L') else 'l_'
            self.renames[name] = f'{prefix}flap_tu{self.ordinal}_{i}'

    def translated(self, name):
        return self.renames.get(name, name)

    def render(self):
        # In separate assembly files the initial mode is ARM. Thumb TUs switch
        # with .code 16, but an ARM TU need not emit a .code 32 directive.
        lines = ['.text', '.arm']
        for i, line in enumerate(self.lines):
            if i in self.omit:
                continue
            # The quoted payload of a literal is data, even when it spells a label.
            if line.lstrip().startswith(('.asciz', '.ascii', '@')):
                lines.append(line)
            else:
                lines.append(TOKEN.sub(lambda m: self.translated(m[0]), line))
        return '\n'.join(lines + self.extra) + '\n'


def merge_objc_assembly(runtime, implementations, owners):
    """Write the merged Apple502 A32/Thumb assembly to runtime and return its path."""
    runtime = Path(runtime)
    canon = Unit(runtime, runtime, 0)
    donors = [Unit(src, asm, index) for index, (src, asm) in
              enumerate(sorted(implementations.items()), 1) if Path(asm) != runtime]
    owners = {name: Path(src).resolve() for name, src in owners.items()}
    units = [canon, *donors]
    by_method = defaultdict(list)
    class_owners = {}
    methods_to_keep = defaultdict(set)
    for unit in units:
        for cls in sorted(unit.classes):
            if cls not in canon.classes:
                if cls in class_owners:
                    raise ValueError(f'{cls} is split across sources but has no canonical class')
                class_owners[cls] = unit
                continue
            for sign in RO:
                for method in unit.methods(cls, sign):
                    by_method[method.identity].append(method)

    elected = defaultdict(list)
    for name, candidates in by_method.items():
        available = [m for m in candidates if m.unit is not canon] or candidates
        if len(available) > 1:
            available = [m for m in available if m.unit.source.resolve() == owners.get(name)]
        if len(available) != 1:
            raise ValueError(f'ambiguous method {name}: {[str(m.unit.source) for m in candidates]}')
        method = available[0]
        methods_to_keep[method.unit].add(method.fields[2])
        elected[method.cls, method.sign].append(method)

    # A weak protocol may be emitted by several header users. Coalesce the
    # symbol exactly once here, giving precedence to the canonical declarations.
    weak = set()
    for unit in units:
        for name in unit.weak:
            if name in weak:
                if not PROTO.fullmatch(name):
                    raise ValueError(f'{unit.source}: unsupported duplicate weak symbol {name}')
                unit.remove(name)
            weak.add(name)
        if unit is not canon:
            for cls in unit.classes & canon.classes:
                unit.remove_class(cls)
            if 'L_OBJC_IMAGE_INFO' in unit.labels:
                if unit.longs('L_OBJC_IMAGE_INFO') != canon.longs('L_OBJC_IMAGE_INFO'):
                    raise ValueError(f'{unit.source}: incompatible Objective-C image flags')
                unit.remove('L_OBJC_IMAGE_INFO')
        # Native categories and unsplit new classes retain their public IMP spelling.
        for label in unit.labels:
            if re.fullmatch(r'"[+-]\[[^ ]+\([^)]*\) .+\]"', label):
                methods_to_keep[unit].add(label)
            elif any(label.startswith(f'"{sign}[{cls} ') for cls in class_owners for sign in RO
                     if class_owners[cls] is unit):
                methods_to_keep[unit].add(label)
        unit.namespace(methods_to_keep[unit])

    # Repoint the sixth 32-bit word of each class_ro_t at the merged triples.
    # All other fields (including property, protocol and ivar metadata) stay
    # compiler-owned. Non-lazy class registration gives +load its real timing.
    nonlazy_label = 'L_OBJC_LABEL_NONLAZY_CLASS_$'
    existing = set(canon.longs(nonlazy_label)) if nonlazy_label in canon.labels else set()
    required = set()
    for index, ((cls, sign), methods) in enumerate(sorted(elected.items())):
        ro = RO[sign] + cls
        old = canon.longs(ro)[5]
        if old != '0':
            canon.remove(old)
        listing = f'l_flap_editable_methods_{index}'
        canon.lines[canon.data(ro).start + 5] = f'\t.long {listing}'
        canon.extra.extend(['.section __DATA,__objc_const', '.align 2', listing + ':',
                            '\t.long 12', f'\t.long {len(methods)}'])
        for method in methods:
            canon.extra.extend('\t.long ' + method.unit.translated(ref) for ref in method.fields)
            if sign == '+' and method.selector == 'load':
                required.add(CLASS + cls)
    if required - existing:
        canon.extra.extend(['.section __DATA,__objc_nlclslist,regular,no_dead_strip', '.align 2'])
        canon.extra.extend('\t.long ' + name for name in sorted(required - existing))

    runtime.write_text(''.join(unit.render() for unit in units))
    return runtime
