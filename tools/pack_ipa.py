"""Repackage Flappy Bird 1.2 using freshly compressed executable bytes.

The original Unix ZIP 2.3 entry uses Info-ZIP level 8. This was checked
against the Info-ZIP 2.3 release (zip23.tar.gz SHA-256
aa8aa89b41f1f0983d044966a42d95df4ceeecef3fa888adb9d38ede4dd3e649)
and macOS /usr/bin/zip 3.0. Both produce the same raw DEFLATE stream.
The package preserves the reference's resources, offsets, timestamps and
ZIP headers and verifies the digest of the final IPA before replacement.
"""
from hashlib import sha256
import os
from pathlib import Path
import shutil
import struct
import sys
import subprocess
import tempfile
import zipfile
import zlib

from verify import EXECUTABLE

IPA_SHA256 = "b306da69c5555b1e55aab1fd2e41708c4b1b53cb1893bc9a7f6bcc84d08e57bb"
DEFLATE_SHA256 = "5abb190e8629cbc4569ffbccf50591211351bd75657fa0385430813fe946135a"
LOCAL_HEADER = struct.Struct("<4s5H3I2H")


def member_span(stream, member):
    """Locate a member's compressed bytes using the original local header."""
    stream.seek(member.header_offset)
    sig, _, flags, method, _, _, crc, size, plain, name_len, extra_len = LOCAL_HEADER.unpack(
        stream.read(LOCAL_HEADER.size))
    if (sig != b"PK\x03\x04" or method != zipfile.ZIP_DEFLATED or flags & 9
            or crc != member.CRC or size != member.compress_size or plain != member.file_size
            or stream.read(name_len) != member.filename.encode("ascii")):
        raise ValueError(f"Unexpected ZIP local header for {member.filename}")
    return stream.tell() + extra_len, size


def deflate(executable, scratch):
    zipper = "/usr/bin/zip" if sys.platform == "darwin" else shutil.which("zip")
    if not zipper or not Path(zipper).is_file():
        raise ValueError("Packaging requires Info-ZIP zip (included with macOS)")
    (scratch / "flap").write_bytes(executable)
    # Info-ZIP -8 and -9 set the same ZIP header flags but produce different streams.
    env = {k: v for k, v in os.environ.items() if k not in {"ZIP", "ZIPOPT"}}
    subprocess.run([zipper, "-8", "-q", "member.zip", "flap"], cwd=scratch, env=env, check=True)
    with (scratch / "member.zip").open("rb") as fresh, zipfile.ZipFile(fresh) as archive:
        offset, size = member_span(fresh, archive.getinfo("flap"))
        fresh.seek(offset)
        compressed = fresh.read(size)
    if sha256(compressed).hexdigest() != DEFLATE_SHA256:
        raise ValueError("Fresh DEFLATE stream differs from the Flappy Bird 1.2 reference")
    return compressed


def pack(ipa: Path, executable: bytes, output: Path):
    """Write the byte-exact IPA while skipping the original compressed executable."""
    ipa = Path(ipa).resolve()
    output = Path(output).resolve()
    if output == ipa or (output.exists() and output.samefile(ipa)):
        raise ValueError("Choose an output path different from the input IPA")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as work:
        scratch = Path(work)
        with ipa.open("rb") as src, zipfile.ZipFile(src) as archive:
            member = archive.getinfo(EXECUTABLE)
            if len(executable) != member.file_size or zlib.crc32(executable) != member.CRC:
                raise ValueError("Rebuilt executable differs from the reference ZIP metadata")
            start, size = member_span(src, member)
            compressed = deflate(executable, scratch)
            if len(compressed) != size:
                raise ValueError("Compressed size differs from the reference ZIP metadata")
            src.seek(0)
            prefix = src.read(start)
            src.seek(start + size)
            rebuilt = b"".join((prefix, compressed, src.read()))
        if sha256(rebuilt).hexdigest() != IPA_SHA256:
            raise ValueError("Rebuilt IPA differs from the Flappy Bird 1.2 reference SHA-256")
        staged = scratch / "output.ipa"
        staged.write_bytes(rebuilt)
        os.replace(staged, output)
