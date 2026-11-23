"""Apply a subset of Mach-O ARM relocations using the reference link layout.

Names and destinations come from ObjC metadata, dyld bindings and indirect
symbols. The candidate function's original instruction bytes are never used
to calculate its relocations. Unsupported or ambiguous targets are errors.
"""

import bisect
import functools
import struct
import subprocess
import tempfile
from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass


def word(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def name_at(data, offset):
    return data[offset:data.index(b"\0", offset)].decode("utf-8", "surrogateescape")


@dataclass(frozen=True)
class Section:
    name: str
    segment: str
    addr: int
    size: int
    offset: int
    reloff: int
    nreloc: int
    indirect: int
    stride: int


class Layout:
    def __init__(self, data):
        self.data = data
        commands = {}
        self.sections = []
        pos = 28
        for _ in range(word(data, 16)):
            cmd, length = struct.unpack_from("<II", data, pos)
            commands[cmd] = pos
            if cmd == 1:  # LC_SEGMENT
                for j in range(word(data, pos + 48)):
                    loc = pos + 56 + 68 * j
                    addr, size, off, _, rel, nrel, _, ind, stride = struct.unpack_from("<9I", data, loc + 32)
                    section = data[loc:loc+16].rstrip(b"\0").decode()
                    segment = data[loc+16:loc+32].rstrip(b"\0").decode()
                    self.sections.append(Section(section, segment, addr, size, off, rel,
                                                 nrel, ind, stride))
            pos += length
        self.by_name = {s.name: s for s in self.sections}
        self.commands = commands
        syms, nsyms, strings = struct.unpack_from("<III", data, commands[2] + 8)
        self.names = []
        self.defined = defaultdict(list)
        for i in range(nsyms):
            idx, kind, section, _, addr = struct.unpack_from("<IBBHI", data, syms + 12*i)
            name = name_at(data, strings + idx)
            self.names.append(name)
            if section and (kind & 0xee) == 0x0e:
                self.defined[addr].append(name)

    def section_at(self, addr):
        for s in self.sections:
            if s.addr <= addr < s.addr + s.size:
                return s
        raise ValueError(f"address {addr:#x} is outside mapped sections")

    def file_offset(self, addr):
        s = self.section_at(addr)
        return s.offset + addr - s.addr

    def read(self, addr):
        return word(self.data, self.file_offset(addr))

    def string(self, addr):
        return name_at(self.data, self.file_offset(addr))

    def cfstring(self, addr):
        # The 32-bit constant CFString layout is {isa, flags, characters, length}.
        flags = self.read(addr + 4)
        length = self.read(addr + 12)
        if flags not in (0x7c8, 0x7d0):
            raise ValueError(f"unsupported constant CFString flags {flags:#x}")
        nbytes = length * (2 if flags == 0x7d0 else 1)
        start = self.file_offset(self.read(addr + 8))
        return flags, length, self.data[start:start+nbytes]

    def pointers(self, section):
        s = self.by_name[section]
        return range(s.addr, s.addr + s.size, 4)


@functools.lru_cache(maxsize=12)
def object_layout(data):
    layout = Layout(data)
    # The ARM backend can combine file-static variables into __MergedGlobals.
    # The spelling is shared by unrelated objects, so identify that storage
    # through a unique class defined by the translation unit.
    classes = [name.split("$_", 1)[1] for names in layout.defined.values() for name in names
               if name.startswith("_OBJC_CLASS_$_")]
    if len(classes) == 1:
        for names in layout.defined.values():
            if "__MergedGlobals" in names:
                names.append(f"{classes[0]}::__MergedGlobals")
    # Copy and dispose helpers have translation-unit-local compiler names.
    # A class defined in the same object can scope their independent anchors.
    for names in layout.defined.values():
        helpers = [n for n in names if n.startswith(("___copy_helper_block_", "___destroy_helper_block_",
                                                     "___Block_byref_object_copy_", "___Block_byref_object_dispose_"))]
        names.extend(f"{owner}::{helper}" for owner in classes for helper in helpers)
    layout.relocations = {}
    layout.external = {}
    for s in layout.sections:
        entries = []
        i = 0
        while i < s.nreloc:
            off, desc = struct.unpack_from("<II", data, s.reloff + i * 8)
            i += 1
            if off >> 31:
                kind = off >> 24 & 15
                pair = None
                if kind in (2, 3, 8, 9):
                    if i >= s.nreloc:
                        raise ValueError("missing paired relocation")
                    pair = struct.unpack_from("<II", data, s.reloff + i * 8)
                    if pair[0] & (1 << 31):
                        pair_kind = pair[0] >> 24 & 15
                    else:
                        pair_kind = pair[1] >> 28
                    if pair_kind != 1:
                        raise ValueError("expected ARM_RELOC_PAIR")
                    i += 1
                entries.append((s.addr + (off & 0xffffff), off, desc, pair))
            else:
                # Non-scattered HALF relocations also consume a PAIR.
                pair = None
                if (desc >> 28) == 8:
                    if i >= s.nreloc:
                        raise ValueError("unpaired HALF relocation")
                    pair = struct.unpack_from("<II", data, s.reloff + i * 8)
                    i += 1
                entries.append((s.addr + off, off, desc, pair))
                if (desc >> 27) == 1:  # external VANILLA
                    layout.external[s.addr + off] = layout.names[desc & 0xffffff]
        layout.relocations[s.name] = sorted(entries)
    if "__nl_symbol_ptr" in layout.by_name and 11 in layout.commands:
        table = word(data, layout.commands[11] + 56)
        sec = layout.by_name["__nl_symbol_ptr"]
        for j, ptr in enumerate(layout.pointers(sec.name)):
            idx = word(data, table + 4*(sec.indirect + j))
            if idx < len(layout.names):
                layout.external[ptr] = layout.names[idx]
    return layout


class Reference(Layout):
    def __init__(self, data):
        super().__init__(data)
        self.targets = defaultdict(set)
        self.exception_records = {}
        cls_names = {}
        ivar_names = {}
        for entry in self.pointers("__objc_classlist"):
            cls = self.read(entry)
            ro = self.read(cls + 16) & ~3
            name = self.string(self.read(ro + 16))
            cls_names[cls] = "_OBJC_CLASS_$_" + name
            cls_names[self.read(cls)] = "_OBJC_METACLASS_$_" + name
            ivars = self.read(ro + 28)
            if ivars:
                stride = self.read(ivars)
                for j in range(self.read(ivars + 4)):
                    ivar = ivars + 8 + stride*j
                    field = self.string(self.read(ivar + 4))
                    symbol = "_OBJC_IVAR_$_" + name + "." + field
                    address = self.read(ivar)
                    self.targets[symbol].add(address)
                    ivar_names[address] = symbol

        for addr, name in cls_names.items():
            self.targets[name].add(addr)
        for addr in self.pointers("__objc_selrefs"):
            self.targets[("__objc_selrefs", self.string(self.read(addr)))].add(addr)
        protocols = {self.read(p) for p in self.pointers("__objc_protolist")}
        for addr in self.pointers("__objc_protorefs"):
            protocol = self.read(addr)
            if protocol in protocols:
                self.targets[("__objc_protorefs", self.string(self.read(protocol + 4)))].add(addr)
        for section in ("__objc_classrefs", "__objc_superrefs"):
            for addr in self.pointers(section):
                if self.read(addr) in cls_names:
                    self.targets[(section, cls_names[self.read(addr)])].add(addr)

        # Imported classes have no in-image class_t. dyld's bind table names them.
        with tempfile.NamedTemporaryFile() as f:
            f.write(data)
            f.flush()
            result = subprocess.run(["xcrun", "llvm-objdump", "--macho", "--bind", f.name],
                                    check=True, capture_output=True, text=True)
        self.add_bound_symbols(result.stdout)

        # An ARM stub can be called with BLX from Thumb. Tail calls require
        # the linker's Thumb->ARM interworking island for that same stub.
        indirect = word(data, self.commands[11] + 56)  # LC_DYSYMTAB.indirectsymoff
        stubs = self.by_name["__symbolstub1"]
        for i in range(stubs.size // stubs.stride):
            name = self.names[word(data, indirect + 4*(stubs.indirect+i))]
            self.targets[("stub", name)].add(stubs.addr + i*stubs.stride)
        s = self.by_name["__text"]
        # Only accept this complete ld64 island sequence plus a displacement
        # which independently resolves to an indirect-symbol stub.
        code = data[s.offset:s.offset+s.size]
        for i in range(0, len(code)-11, 4):
            if code[i:i+8] == bytes.fromhex("dff804c0fc446047"):
                island = s.addr+i
                stub = (island + 8 + word(code, i+8)) & 0xffffffff
                if stubs.addr <= stub < stubs.addr + stubs.size and (stub-stubs.addr) % stubs.stride == 0:
                    self.targets[("island", stub)].add(island)
        for addr in self.pointers("__nl_symbol_ptr"):
            # An executable's __dso_handle denotes its Mach-O header. ld64
            # resolves this locally, leaving no dynamic bind name for the slot.
            if "__mh_execute_header" in self.defined.get(self.read(addr), ()):
                self.targets[("__nl_symbol_ptr", "___dso_handle")].add(addr)
            # Nonlazy references to image-defined ivars carry a local pointer.
            ivar = ivar_names.get(self.read(addr))
            if ivar is not None:
                self.targets[("__nl_symbol_ptr", ivar)].add(addr)
            s = self.by_name["__nl_symbol_ptr"]
            idx = word(data, indirect + 4*s.indirect + addr - s.addr)
            if idx < len(self.names):
                self.targets[("__nl_symbol_ptr", self.names[idx])].add(addr)

        # Names in this stripped image are recovered from independent callers
        # and data accesses. See each anchor's evidence in layout/*.tsv.
        from verify import Image
        image = Image(data)
        for path in sorted((Path(__file__).resolve().parents[1] / "layout").glob("*.tsv")):
            for line in path.read_text().splitlines():
                if not line or line.startswith("#"):
                    continue
                symbol, kind, v7, v7s, evidence = line.split("\t")
                addr = int(v7 if image.arch == "armv7" else v7s, 16)
                if not evidence.strip():
                    raise ValueError(f"no anchor evidence for {symbol}")
                if kind == "pointer":
                    self.section_at(addr)  # validate the original global's address
                    for entry in self.pointers("__nl_symbol_ptr"):
                        if self.read(entry) == addr:
                            self.targets[("__nl_symbol_ptr", symbol)].add(entry)
                    self.targets[symbol].add(addr)
                elif kind in ("arm", "thumb"):
                    if image.starts.get(addr) != (kind == "thumb"):
                        raise ValueError(f"{path.name}: {symbol} is not a {kind} entry at {addr:#x}")
                    self.targets[(kind, symbol)].add(addr)
                elif kind.startswith("lsda") and kind[4:].isdigit() and symbol.endswith("::LSDA"):
                    length = int(kind[4:])
                    section = self.section_at(addr)
                    if (length <= 0 or section.name != "__gcc_except_tab" or
                            addr + length > section.addr + section.size or symbol in self.exception_records):
                        raise ValueError(f"invalid or duplicate exception record for {symbol}")
                    self.exception_records[symbol] = (addr, length)
                else:
                    raise ValueError(f"unknown anchor kind {kind!r}")
        # Content-based coalescing is unambiguous only if the string has one
        # physical location. Include suffixes because ld also merges tails.
        self.cstrings = self.by_name["__cstring"]
        cf = self.by_name["__cfstring"]
        for addr in range(cf.addr, cf.addr + cf.size, 16):
            self.targets[("__cfstring", self.cfstring(addr))].add(addr)

    def add_bound_symbols(self, output):
        for row in output.splitlines():
            fields = row.split()
            # The seventh column names the symbol; weak imports have a trailing annotation.
            if len(fields) >= 7 and fields[1] in ("__objc_classrefs", "__objc_superrefs", "__nl_symbol_ptr"):
                self.targets[(fields[1], fields[6])].add(int(fields[2], 16))
            elif len(fields) >= 7 and fields[1] == "__const" and fields[6] == "__NSConcreteGlobalBlock":
                self.targets[("global_block",)].add(int(fields[2], 16))

    def string_literal(self, literal):
        sec = self.cstrings
        data = self.data[sec.offset:sec.offset+sec.size]
        pattern = literal + b"\0"
        pos = 0
        exact = []
        while True:
            i = data.find(pattern, pos)
            if i < 0:
                break
            if i == 0 or data[i-1] == 0:
                exact.append(i)
            pos = i + 1
        if len(exact) == 1:
            return sec.addr + exact[0]
        i = data.find(pattern)
        if i == -1 or data.find(pattern, i+1) != -1:
            raise ValueError(f"missing or ambiguous C string {literal!r}")
        return sec.addr + i

    def unique(self, key):
        vals = self.targets.get(key, set())
        if len(vals) != 1:
            raise ValueError(f"expected one original link target for {key!r}, found {len(vals)}")
        return next(iter(vals))

    def exception_target(self, obj, addr, function_start):
        section = obj.by_name["__gcc_except_tab"]
        linked = self.by_name[section.name]
        start, end = section.addr, section.addr + section.size
        anchors = {self.exception_records[n + "::LSDA"] for n in obj.defined.get(function_start, ())
                   if n + "::LSDA" in self.exception_records}
        if anchors:
            if len(anchors) != 1 or not any(n.startswith("GCC_except_table") for n in obj.defined[addr]):
                raise ValueError("unmapped or ambiguous exception record")
            target, length = anchors.pop()
            start = addr
            end = min((p for p, names in obj.defined.items() if addr < p < end and
                       any(n.startswith("GCC_except_table") for n in names)), default=end)
            if end - start != length:
                raise ValueError("unmapped exception record length")
            candidates = [target]
        else:
            candidates = range(linked.addr, linked.addr + linked.size - (end - start) + 1)

        raw = obj.data[obj.file_offset(start):obj.file_offset(start) + end - start]
        fixups = []
        for pos, flags, dest, pair in obj.relocations[section.name]:
            if not start <= pos < end:
                continue
            if (flags >> 24 not in (0xa2, 0xa3) or not pair or pair[0] != 0xa1000000 or
                    pair[1] != pos or pos + 4 > end or obj.read(pos) != (dest - pos) & 0xffffffff or
                    obj.section_at(dest).name != "__nl_symbol_ptr"):
                raise ValueError("unsupported exception-table relocation")
            fixups.append((pos - start, self.target(obj, dest)))

        original = self.data[linked.offset:linked.offset + linked.size]
        prefix = raw[:fixups[0][0]] if fixups else raw
        matches = []
        for where in candidates:
            offset = where - linked.addr
            if not original.startswith(prefix, offset):
                continue
            relocated = bytearray(raw)
            for field, pointer in fixups:
                struct.pack_into("<I", relocated, field, (pointer - (where + field)) & 0xffffffff)
            if original.startswith(relocated, offset):
                matches.append(where)
        if len(matches) != 1:
            raise ValueError("unmapped or ambiguous exception tables")
        return matches[0] + addr - start

    def target(self, obj, addr, function_start=None):
        sec = obj.section_at(addr).name
        if sec == "__literal16":
            literal = obj.by_name[sec]
            if literal.nreloc or (addr - literal.addr) % 16 or addr + 16 > literal.addr + literal.size:
                raise ValueError("unsupported partial or relocated 16-byte literal")
            offset = obj.file_offset(addr)
            value = obj.data[offset:offset + 16]
            locations = []
            for section in self.sections:
                if section.segment != "__TEXT" or section.name not in ("__const", "__literal16"):
                    continue
                data = self.data[section.offset:section.offset + section.size]
                pos = data.find(value)
                while pos >= 0:
                    if (section.addr + pos) % 4 == 0:
                        locations.append(section.addr + pos)
                    pos = data.find(value, pos + 1)
            if len(locations) != 1:
                raise ValueError("unmapped or ambiguous 16-byte literal")
            return locations[0]
        if sec == "__const" and obj.external.get(addr) == "__NSConcreteGlobalBlock":
            # Captureless global blocks have a 20-byte header on 32-bit iOS.
            # Match the independently placed invoke function and descriptor
            # against actual dyld-bound block literals in the executable.
            flags = obj.read(addr + 4)
            desc = obj.read(addr + 16)
            if (flags != 0x50000000 or obj.read(addr + 8) or
                    obj.read(desc) or obj.read(desc + 4) != 20):
                raise ValueError("unsupported global block descriptor")
            invoke = self.target(obj, obj.read(addr + 12) & ~1)
            signature = obj.string(obj.read(desc + 8))
            found = []
            for block in self.targets[("global_block",)]:
                if (self.read(block + 4) != flags or self.read(block + 8) or
                        (self.read(block + 12) & ~1) != invoke):
                    continue
                descriptor = self.read(block + 16)
                if (self.read(descriptor) == 0 and self.read(descriptor + 4) == 20 and
                        self.string(self.read(descriptor + 8)) == signature):
                    found.append(block)
            if len(found) != 1:
                raise ValueError("missing or ambiguous linked global block")
            return found[0]
        if sec == "__const" and any(n.startswith("___block_descriptor_") for n in obj.defined[addr]):
            # Clang encodes up to 15 strong, byref and weak captures apiece
            # in three nibbles. Larger layouts use a separate layout string.
            size = obj.read(addr + 4)
            layout = obj.read(addr + 20)
            captures = (layout >> 8) + ((layout >> 4) & 15) + (layout & 15)
            if (obj.read(addr) != 0 or not 0 < layout < 0x1000 or
                    size < 20 + 4 * captures):
                raise ValueError("unsupported captured block descriptor")
            helpers = []
            for offset in (8, 12):
                pointer = obj.read(addr + offset)
                helpers.append(self.target(obj, pointer & ~1) | (pointer & 1))
            signature = obj.string(obj.read(addr + 16))
            section = self.by_name["__const"]
            found = []
            for p in range(section.addr, section.addr + section.size - 23, 4):
                if (self.read(p) == 0 and self.read(p + 4) == size and
                        self.read(p + 8) == helpers[0] and self.read(p + 12) == helpers[1] and
                        self.read(p + 20) == layout and self.string(self.read(p + 16)) == signature):
                    found.append(p)
            if len(found) != 1:
                raise ValueError("missing or ambiguous captured block descriptor")
            return found[0]
        if sec == "__gcc_except_tab":
            return self.exception_target(obj, addr, function_start)
        if sec == "__text":
            candidates = [(kind, symbol) for symbol in obj.defined[addr]
                          for kind in ("arm", "thumb") if (kind, symbol) in self.targets]
            if len(candidates) == 1:
                return self.unique(candidates[0])
        if sec == "__cfstring":
            return self.unique((sec, obj.cfstring(addr)))
        if sec == "__cstring":
            pos = obj.file_offset(addr)
            return self.string_literal(obj.data[pos:obj.data.index(b"\0", pos)])
        if sec == "__objc_selrefs":
            return self.unique((sec, obj.string(obj.read(addr))))
        if sec == "__objc_protorefs":
            protocol = obj.read(addr)
            if "__objc_protolist" in obj.by_name:
                entries = obj.pointers("__objc_protolist")
                symbol = obj.external.get(addr)
                if symbol and not protocol and symbol.startswith("l_OBJC_PROTOCOL_$_"):
                    if any(obj.external.get(p) == symbol and not obj.read(p) for p in entries):
                        return self.unique((sec, symbol.split("$_", 1)[1]))
                elif not symbol and protocol and any(obj.read(p) == protocol for p in entries):
                    return self.unique((sec, obj.string(obj.read(protocol + 4))))
            raise ValueError("unmapped Objective-C protocol reference")
        if sec in ("__objc_classrefs", "__objc_superrefs"):
            name = obj.external.get(addr)
            if not name:
                candidates = [n for n in obj.defined[obj.read(addr)]
                              if n.startswith(("_OBJC_CLASS_$_", "_OBJC_METACLASS_$_"))]
                if len(candidates) != 1:
                    raise ValueError(f"class reference at {addr:#x} is ambiguous")
                name = candidates[0]
            return self.unique((sec, name))
        if sec == "__nl_symbol_ptr" and addr in obj.external:
            return self.unique((sec, obj.external[addr]))
        names = [name for name in obj.defined[addr] if name in self.targets]
        if len(names) == 1:
            return self.unique(names[0])
        raise ValueError(f"no symbol mapping for {sec} at object address {addr:#x}: {obj.defined[addr]}")


reference_layout = functools.lru_cache(maxsize=2)(Reference)


def apply_difference(buf, offset, flags, desc, pair, placed_address, start, end, obj, ref):
    if pair is None or not pair[0] >> 31:
        raise ValueError("missing scattered difference anchor")
    anchor = pair[1]
    if not start <= anchor < end:
        raise ValueError("difference anchor is outside the function")
    insn = word(buf, offset)
    high = bool(flags & (1 << 28))
    thumb = bool(flags & (1 << 29))
    if thumb:
        if insn & 0x8000fbf0 != (0xf2c0 if high else 0xf240):
            raise ValueError("HALF_SECTDIFF is not on its expected Thumb MOVW/MOVT")
        imm = ((insn & 15) << 12 | (insn & 0x400) << 1 |
               (insn >> 20 & 0x700) | (insn >> 16 & 0xff))
    else:
        if insn & 0x0ff00000 != (0x03400000 if high else 0x03000000):
            raise ValueError("HALF_SECTDIFF is not on its expected ARM MOVW/MOVT")
        imm = (insn >> 4 & 0xf000) | (insn & 0xfff)
    other = pair[0] & 0xffff
    before = (imm << 16 | other) if high else (other << 16 | imm)
    anchor_slide = placed_address(anchor) - anchor
    after = before + (ref.target(obj, desc, start) - desc) - anchor_slide
    half = (after >> 16 if high else after) & 0xffff
    if thumb:
        patched = (insn & ~0x70ff040f) | (half >> 12) | (half & 0x800) >> 1
        patched |= (half & 0x700) << 20 | (half & 0xff) << 16
    else:
        patched = insn & ~0x000f0fff | (half & 0xf000) << 4 | (half & 0xfff)
    struct.pack_into("<I", buf, offset, patched)


def branch_target(ref, name):
    if ("thumb", name) in ref.targets:
        return ref.unique(("thumb", name)), True
    if ("arm", name) in ref.targets:
        return ref.unique(("arm", name)), False
    return ref.unique(("stub", name)), False


def apply_branch(buf, offset, obj_pc, dest_pc, desc, obj, ref):
    a, b = struct.unpack_from("<HH", buf, offset)
    opcode = b & 0xd000
    if a & 0xf800 != 0xf000 or opcode not in (0x9000, 0xc000, 0xd000):
        raise ValueError("unsupported Thumb branch relocation")
    call = opcode != 0x9000
    s = a >> 10 & 1
    i1 = 1 ^ s ^ (b >> 13 & 1)
    i2 = 1 ^ s ^ (b >> 11 & 1)
    delta = s << 24 | i1 << 23 | i2 << 22 | (a & 0x3ff) << 12 | (b & 0x7ff) << 1
    if s:
        delta -= 1 << 25
    obj_base = (obj_pc + 4) & (~3 if opcode == 0xc000 else ~0)
    target_in_object = obj_base + delta
    if desc & (1 << 27):
        symbol = obj.names[desc & 0xffffff]
        if target_in_object != 0:
            raise ValueError(f"unsupported addend on branch to {symbol}: {target_in_object}")
    else:
        names = [n for n in obj.defined[target_in_object] if ("thumb", n) in ref.targets
                 or ("arm", n) in ref.targets]
        if len(names) != 1:
            raise ValueError(f"unmapped local branch target {target_in_object:#x}: {obj.defined[target_in_object]}")
        symbol = names[0]
    target, thumb = branch_target(ref, symbol)
    if not call and not thumb:
        target = ref.unique(("island", target))
        thumb = True
    dest_base = (dest_pc + 4) & (~0 if thumb else ~3)
    delta = target - dest_base
    b = (0xd000 if thumb else 0xc000) if call else 0x9000
    if not -(1 << 24) <= delta < 1 << 24 or delta & (1 if thumb else 3):
        raise ValueError("branch out of range or misaligned")
    s, i1, i2 = (delta >> 24) & 1, (delta >> 23) & 1, (delta >> 22) & 1
    a = 0xf000 | s << 10 | (delta >> 12 & 0x3ff)
    b |= (1 ^ s ^ i1) << 13 | (1 ^ s ^ i2) << 11 | (delta >> 1 & 0x7ff)
    struct.pack_into("<HH", buf, offset, a, b)


def link_function(obj_data, original_slice, object_start_vm, original_start_vm, length, *, placed_address=None):
    return relocate_function(object_layout(obj_data), reference_layout(original_slice),
                             object_start_vm, original_start_vm, length, placed_address=placed_address)


def relocate_function(obj, ref, object_start_vm, original_start_vm, length, *, placed_address=None):
    """Resolve relocations using the final address of each compiler instruction.

    Return the bytes in input order. A vendor layout pass may expand the input
    after relocation. A HALF_SECTDIFF is relative to its paired PC anchor,
    which can move independently of the MOVW or MOVT carrying the difference.
    """
    pos = obj.file_offset(object_start_vm)
    buf = bytearray(obj.data[pos:pos+length])
    if placed_address is None:
        def placed_address(pc):
            return original_start_vm + (pc - object_start_vm)
    end = object_start_vm + length
    relocs = obj.relocations[obj.section_at(object_start_vm).name]
    i = bisect.bisect_left(relocs, (object_start_vm,))
    while i < len(relocs) and relocs[i][0] < end:
        addr, flags, desc, pair = relocs[i]
        offset = addr - object_start_vm
        if offset + 4 > length:
            raise ValueError("relocation extends beyond function")
        if flags >> 31 and (flags >> 24 & 15) == 9:
            apply_difference(buf, offset, flags, desc, pair, placed_address, object_start_vm, end, obj, ref)
        elif flags >> 24 in (0xa2, 0xa3):  # 32-bit SECTDIFF or LOCAL_SECTDIFF
            if (not pair or not pair[0] >> 31 or not object_start_vm <= pair[1] < end
                    or obj.section_at(desc).name != "__gcc_except_tab"):
                raise ValueError("unsupported ARM exception-table difference")
            anchor_slide = placed_address(pair[1]) - pair[1]
            value = word(buf, offset) + ref.target(obj, desc, object_start_vm) - desc - anchor_slide
            struct.pack_into("<I", buf, offset, value & 0xffffffff)
        elif not flags >> 31 and (desc >> 24) in (0x6d, 0x65):
            apply_branch(buf, offset, addr, placed_address(addr), desc, obj, ref)
        elif not flags >> 31 and (desc >> 24) in (0x5d, 0x55):  # ARM BR24
            insn = word(buf, offset)
            if (insn & 0x0e000000) != 0x0a000000 or (insn >> 28) == 15:
                raise ValueError("unsupported ARM branch encoding")
            delta = ((insn & 0xffffff) ^ 0x800000) - 0x800000
            destination = addr + 8 + 4*delta
            if desc & (1 << 27):
                if destination:
                    raise ValueError("unsupported addend on external ARM branch")
                symbol = obj.names[desc & 0xffffff]
            else:
                names = [n for n in obj.defined[destination] if ("arm", n) in ref.targets]
                if len(names) != 1:
                    raise ValueError(f"unmapped local ARM branch at {destination:#x}")
                symbol = names[0]
            target, thumb = branch_target(ref, symbol)
            delta = target - (placed_address(addr) + 8)
            if thumb or delta % 4 or not -(1 << 25) <= delta < (1 << 25):
                raise ValueError("unsupported ARM branch destination")
            struct.pack_into("<I", buf, offset, (insn & 0xff000000) | ((delta >> 2) & 0xffffff))
        else:
            raise ValueError(f"unsupported relocation at object address {addr:#x} ({flags:#x}, {desc:#x})")
        i += 1
    return bytes(buf)
