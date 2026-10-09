#!/usr/bin/env python3
"""Check shipped code against tested source and the actual release ZIP."""
from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from verify_manifest import collect, local


def normalized(data: bytes) -> bytes:
    # BigWigs may convert text to CRLF; code must otherwise remain identical.
    return data.replace(b"\r\n", b"\n")


def verify(root: Path, source: Path, archive: Path) -> list[str]:
    problems: list[str] = []
    seen: set[Path] = set()
    manifest = root / "manifest.xml"
    if not manifest.is_file():
        return ["packaged manifest.xml is missing"]
    collect(manifest, root, seen, problems)
    if problems:
        return problems

    # Check every loaded XML/Lua file, not just whether a filename exists.
    expected: set[Path] = {Path("manifest.xml")}
    source_seen: set[Path] = set()
    collect(source / "manifest.xml", source, source_seen, problems)
    if problems:
        return problems
    for xml in source_seen:
        expected.add(xml.relative_to(source))
        for node in ET.parse(xml).getroot().iter():
            if local(node.tag) in ("Include", "Script"):
                target = xml.parent / node.get("file", "").replace("\\", "/")
                expected.add(target.relative_to(source))
    for rel in sorted(expected):
        shipped = root / rel
        if not shipped.is_file():
            problems.append(f"packaged file missing: {rel}")
        elif normalized(shipped.read_bytes()) != normalized((source / rel).read_bytes()):
            problems.append(f"packaged code differs from tested source: {rel}")

    try:
        with zipfile.ZipFile(archive) as z:
            if z.testzip() is not None:
                problems.append("release ZIP has a damaged entry")
            names = z.namelist()
            if len(names) != len(set(names)):
                problems.append("release ZIP has duplicate entries")
            files = {root.name + "/" + str(p.relative_to(root)): p
                     for p in root.rglob("*") if p.is_file()}
            zipped = {n for n in names if not n.endswith("/")}
            for name in sorted(set(files) - zipped):
                problems.append(f"release ZIP is missing {name}")
            for name in sorted(zipped - set(files)):
                problems.append(f"release ZIP contains an unexpected file: {name}")
            for name in sorted(set(files) & zipped):
                if z.read(name) != files[name].read_bytes():
                    problems.append(f"release ZIP differs from packaged folder: {name}")
    except (OSError, zipfile.BadZipFile) as exc:
        problems.append(f"cannot verify release ZIP: {exc}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--archive", required=True)
    args = parser.parse_args()
    problems = verify(Path(args.root).resolve(), Path(__file__).resolve().parent.parent,
                      Path(args.archive).resolve())
    for problem in problems:
        print(f"error: {problem}", file=sys.stderr)
    if problems:
        return 1
    print("package OK: load chain, tested runtime code and release ZIP match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
