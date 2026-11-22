#!/usr/bin/env python3
"""Pack the editable game and the inputs to its matching build."""
from pathlib import Path
from tempfile import TemporaryDirectory
import zipfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/Flappy Bird source.zip"


def project_files():
    yield from (ROOT / name for name in (".gitignore", "Makefile", "README.md", "recovered/README.md"))
    for directory in ("assets", "src", "matches", "layout", "assembly", "tools"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.is_file() and not set(path.parts) & {"__pycache__", ".git"}:
                if not path.name.startswith(".") and path.suffix != ".pyc":
                    yield path


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=OUTPUT.parent) as tmp:
        candidate = Path(tmp) / OUTPUT.name
        with zipfile.ZipFile(candidate, "w") as archive:
            for path in project_files():
                name = "Flappy Bird source/" + path.relative_to(ROOT).as_posix()
                entry = zipfile.ZipInfo(name)
                entry.create_system = 3
                entry.external_attr = (0o100000 | (path.stat().st_mode & 0o777)) << 16
                archive.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
        candidate.replace(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
