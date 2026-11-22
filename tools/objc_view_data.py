"""Link dot_EAGLView's compiler-emitted method, ivar and property metadata."""
from functools import lru_cache
import struct
import subprocess

from linkmatch import Layout, reference_layout
from verify import Image, ROOT, find_tool, read_manifests


CLASS = "dot_EAGLView"


def class_records(image):
    for entry in image.pointers("__objc_classlist"):
        cls = image.read(entry)
        record = image.read(cls + 16) & ~3
        if image.string(image.read(record + 16)) == CLASS:
            metaclass = image.read(cls)
            return record, image.read(metaclass + 16) & ~3
    raise ValueError(f"no Objective-C metadata for {CLASS}")


def linked_objc_metadata(image, tmp):
    """Return (slice file offset, bytes) ranges rebuilt from the Objective-C source."""
    obj_path = tmp / f"view-metadata-{image.arch}.o"
    subprocess.run([find_tool("clang"), "-target", f"{image.arch}-apple-ios7.0", "-mthumb",
                    "-Os", "-ffreestanding", "-isysroot", "/", "-c", ROOT / "src/view.m",
                    "-o", obj_path], check=True)
    obj = Layout(obj_path.read_bytes())
    symbols = Image(obj.data).symbols
    ref = reference_layout(image.data)
    compiled_class, compiled_meta = class_records(obj)
    linked_class, linked_meta = class_records(ref)
    methods = {r.symbol: r.address for r in read_manifests()
               if r.arch == image.arch and r.source == ROOT / "src/view.m"}
    ranges = []
    strings = {}

    def add(vm, section, data):
        mapped = ref.section_at(vm)
        if mapped.name != section or vm + len(data) > mapped.addr + mapped.size:
            raise ValueError(f"{CLASS} data at {vm:#x} is outside {section}")
        offset = ref.file_offset(vm)
        if image.data[offset:offset + len(data)] != data:
            raise ValueError(f"{CLASS} {section} mismatch at {vm:#x}")
        ranges.append((offset, bytes(data)))

    @lru_cache(maxsize=None)
    def string_address(vm, output_section=None):
        # ld64 coalesces and tail-merges these C strings within each section.
        name = obj.section_at(vm).name
        if name not in ("__objc_methname", "__objc_methtype", "__cstring"):
            raise ValueError(f"unexpected Objective-C string section {name}")
        literal = obj.string(vm).encode() + b"\0"
        target = ref.by_name[output_section or name]
        pool = ref.data[target.offset:target.offset + target.size]
        at = pool.find(literal)
        hits = []
        complete = []
        while at >= 0:
            hits.append(at)
            if at == 0 or pool[at - 1] == 0:
                complete.append(at)
            at = pool.find(literal, at + 1)
        matches = complete or hits
        if len(matches) != 1:
            raise ValueError(f"ambiguous linked {name} literal {literal!r}")
        address = target.addr + matches[0]
        strings[(target.name, address)] = literal
        return address

    # 32-bit class_ro_t contains pointers to its lists at fixed ABI offsets.
    # The source declarations set list order, record sizes and scalar fields.
    for owner, linked_owner, field, stride in [
            (compiled_meta, linked_meta, 20, 12), (compiled_class, linked_class, 20, 12),
            (compiled_class, linked_class, 28, 20), (compiled_class, linked_class, 36, 8)]:
        table = obj.read(owner + field)
        target = ref.read(linked_owner + field)
        count = obj.read(table + 4)
        if obj.read(table) != stride:
            raise ValueError(f"unexpected {CLASS} metadata stride at {table:#x}")
        data = bytearray(struct.pack("<II", stride, count))
        for i in range(count):
            entry = table + 8 + i * stride
            if field == 20:
                selector, encoding, imp = (obj.read(entry + k) for k in (0, 4, 8))
                prefix = "+" if owner == compiled_meta else "-"
                symbol = f"{prefix}[{CLASS} {obj.string(selector)}]"
                if symbol not in obj.defined[imp & ~1] or symbol not in methods:
                    raise ValueError(f"unverified method implementation {symbol}")
                words = (string_address(selector), string_address(encoding), methods[symbol] | bool(symbols[symbol].description & 8))
            elif field == 28:
                offset_var, name, encoding, alignment, size = (obj.read(entry + k) for k in range(0, 20, 4))
                symbol = f"_OBJC_IVAR_$_{CLASS}.{obj.string(name)}"
                if symbol not in obj.defined[offset_var]:
                    raise ValueError(f"wrong ivar definition {symbol}")
                address = ref.unique(symbol)
                add(address, "__objc_ivar", struct.pack("<I", obj.read(offset_var)))
                words = (address, string_address(name), string_address(encoding), alignment, size)
            else:
                words = (string_address(obj.read(entry), "__cstring"),
                         string_address(obj.read(entry + 4), "__cstring"))
            data.extend(struct.pack(f"<{len(words)}I", *words))
        add(target, "__objc_const", data)
    # Some strings share a terminator because the linker reused a longer
    # string's suffix. Emit the complete containing string exactly once.
    end = 0
    for (section, address), literal in sorted(strings.items(), key=lambda item: item[0][1]):
        if address >= end:
            add(address, section, literal)
            end = address + len(literal)
        elif address + len(literal) != end:
            raise ValueError(f"unexpected overlap in the {CLASS} string pool")
    return ranges
