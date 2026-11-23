"""Read the 32-bit modern Objective-C protocol ABI from linked Mach-O metadata.

The field order and extended-type indexing follow Apple's objc4-551.1 runtime,
objc-runtime-new.h (protocol_t) and objc-runtime-new.mm
(getExtendedTypesIndexesForMethod).
"""

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True, order=True)
class ProtocolMethod:
    requirement: str
    kind: str
    selector: str
    encoding: str
    extended: Optional[str]


@dataclass(frozen=True, order=True)
class ProtocolProperty:
    kind: str
    name: str
    attributes: str


@dataclass(frozen=True)
class ProtocolDefinition:
    inherited: tuple
    methods: tuple
    properties: tuple


def _range(layout, address, size, *, aligned=True):
    if not address or size < 0 or (aligned and address % 4):
        raise ValueError(f"null or invalid Objective-C metadata address {address:#x}")
    section = layout.section_at(address)
    if (address + size > section.addr + section.size or
            section.offset == 0 or section.offset + address - section.addr + size > len(layout.data)):
        raise ValueError(f"Objective-C metadata exceeds its file-backed section at {address:#x}")
    return section


def _string(layout, address):
    section = _range(layout, address, 1, aligned=False)
    start = section.offset + address - section.addr
    stop = min(len(layout.data), section.offset + section.size)
    end = layout.data.find(b"\0", start, stop)
    if end <= start:
        raise ValueError(f"empty or unterminated Objective-C metadata string at {address:#x}")
    return layout.data[start:end].decode("utf-8")


def _header(layout, protocol):
    _range(layout, protocol, 40)
    name = _string(layout, layout.read(protocol + 4))
    size = layout.read(protocol + 32)
    if size not in (40, 44, 48, 52):
        raise ValueError(f"unsupported 32-bit Objective-C protocol size {size} for {name}")
    _range(layout, protocol, size)
    return name, size


def protocol_names(layout, address):
    """Return the sorted names in a protocol_list_t, or () for an absent list."""
    if not address:
        return ()
    _range(layout, address, 4)
    count = layout.read(address)
    _range(layout, address, 4 + 4 * count)
    names = tuple(sorted(_header(layout, layout.read(address + 4 + 4 * i))[0] for i in range(count)))
    if len(set(names)) != len(names):
        raise ValueError(f"duplicate protocol adoption in list at {address:#x}")
    return names


def _entries(layout, address, stride):
    if not address:
        return ()
    _range(layout, address, 8)
    if layout.read(address) != stride:
        raise ValueError(f"unsupported Objective-C entry size at {address:#x}")
    count = layout.read(address + 4)
    end = address + 8 + stride * count
    _range(layout, address, end - address)
    return range(address + 8, end, stride)


def _definition(layout, protocol):
    name, size = _header(layout, protocol)
    inherited = protocol_names(layout, layout.read(protocol + 8))

    extended = layout.read(protocol + 40) if size >= 44 else 0
    methods = []
    seen = set()
    for offset, requirement, kind in [(12, "required", "instance"), (16, "required", "class"),
                                      (20, "optional", "instance"), (24, "optional", "class")]:
        entries = _entries(layout, layout.read(protocol + offset), 12)
        if extended and entries:
            _range(layout, extended, 4 * (len(methods) + len(entries)))
        for entry in entries:
            selector = _string(layout, layout.read(entry))
            if (kind, selector) in seen:
                raise ValueError(f"duplicate {kind} method {selector} in protocol {name}")
            seen.add((kind, selector))
            encoding = _string(layout, layout.read(entry + 4))
            extra = _string(layout, layout.read(extended + 4 * len(methods))) if extended else None
            methods.append(ProtocolMethod(requirement, kind, selector, encoding, extra))

    properties = []
    for offset, kind in ((28, "instance"), (48, "class")):
        if size < offset + 4:
            continue
        names = set()
        for entry in _entries(layout, layout.read(protocol + offset), 8):
            prop = _string(layout, layout.read(entry))
            if prop in names:
                raise ValueError(f"duplicate {kind} property {prop} in protocol {name}")
            names.add(prop)
            properties.append(ProtocolProperty(kind, prop, _string(layout, layout.read(entry + 4))))
    return name, ProtocolDefinition(inherited, tuple(sorted(methods)), tuple(sorted(properties)))


def protocol_definitions(layout):
    """Return all protocols declared in __objc_protolist, keyed by runtime name."""
    section = layout.by_name.get("__objc_protolist")
    if section is None or not section.size:
        return {}
    if section.size % 4:
        raise ValueError("misaligned Objective-C protocol pointer section")
    _range(layout, section.addr, section.size)
    declarations = {}
    for entry in layout.pointers(section.name):
        name, definition = _definition(layout, layout.read(entry))
        if name in declarations and declarations[name] != definition:
            raise ValueError(f"conflicting definitions of Objective-C protocol {name}")
        declarations[name] = definition
    return declarations
