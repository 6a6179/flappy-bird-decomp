"""Build a mixed native executable and preserve the remaining reference sections."""
from hashlib import sha256
from pathlib import Path
import os
import struct
import tempfile
import zipfile

from verify import ARCHES, CPU_ARM, EXECUTABLE, SLICE_SHA256


def splice_ranges(template, replacements):
    """Copy the gaps and fill every reconstructed file range from compiled bytes."""
    parts = []
    end = 0
    for start, body in sorted(replacements, key=lambda item: item[0]):
        if start < end or not body or start + len(body) > len(template):
            raise ValueError("overlapping, empty or out-of-bounds reconstructed range")
        parts.extend((template[end:start], body))
        end = start + len(body)
    parts.append(template[end:])
    return b"".join(parts)


def rebuilt_executable(ipa, images, compiled, tmp):
    from admob_objects import linked_sdk_objects
    from assembly import assemble_mixed
    from game_vtables import linked_vtables
    from get_admob680 import DEST as admob_library
    from objc_view_data import linked_objc_metadata

    with zipfile.ZipFile(ipa) as archive:
        reference = archive.read(EXECUTABLE)
    ranges = []
    for i in range(struct.unpack_from(">I", reference, 4)[0]):
        cpu, subtype, offset, _, _ = struct.unpack_from(">5I", reference, 8 + 20*i)
        if cpu != CPU_ARM or (subtype & 0xffffff) not in ARCHES:
            raise ValueError("unsupported CPU in universal binary")
        arch = ARCHES[subtype & 0xffffff]
        image = images[arch]
        source = compiled[arch]
        vendor = linked_sdk_objects(image, source) if admob_library.is_file() else {}
        if source.keys() & vendor.keys():
            raise ValueError("AdMob object functions overlap compiled source")
        print(f"{arch}: linked {len(vendor)} additional functions from the AdMob library "
              f"({sum(map(len, vendor.values()))} bytes)")
        text = assemble_mixed(image, source | vendor, tmp)
        tables = linked_vtables(image, tmp)
        metadata = linked_objc_metadata(image, tmp)
        print(f"{arch}: linked {len(tables)} game virtual tables ({sum(len(body) for _, body in tables)} bytes)")
        print(f"{arch}: linked {len(metadata)} view metadata ranges ({sum(len(body) for _, body in metadata)} bytes)")
        thin = splice_ranges(image.data, [(image.text.offset, text), *tables, *metadata])
        if sha256(thin).hexdigest() != SLICE_SHA256[arch]:
            raise ValueError(f"{arch} mixed executable SHA-256 mismatch")
        ranges.append((offset, thin))

    universal = bytearray()
    end = 0
    for offset, thin in sorted(ranges):
        universal.extend(reference[end:offset])  # fat header and inter-slice alignment
        universal.extend(thin)
        end = offset + len(thin)
    universal.extend(reference[end:])
    if universal != reference:
        raise ValueError("rebuilt universal executable differs from the reference")
    return universal


def write_output(ipa, output, images, compiled):
    output = Path(output).resolve()
    if output == Path(ipa).resolve():
        raise ValueError("choose an output path different from the input IPA")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as work:
        tmp = Path(work)
        exe = rebuilt_executable(ipa, images, compiled, tmp)
        artifact = tmp / output.name
        if output.suffix.lower() == ".ipa":
            from pack_ipa import IPA_SHA256, pack
            pack(ipa, exe, artifact)
            print(f"Verified IPA SHA-256 {IPA_SHA256}")
        else:
            artifact.write_bytes(exe)
            artifact.chmod(0o755)
        os.replace(artifact, output)
        print(f"Verified universal executable SHA-256 {sha256(exe).hexdigest()}")
        print(f"Wrote {output}")
