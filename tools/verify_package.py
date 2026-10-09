#!/usr/bin/env python3
"""Validate the actual release directory + ZIP, including external libraries.

The source tree is allowed to lack vendor libraries that get populated later.
Everything referenced at runtime is required inside the package. Pinned hashes
in DEPENDENCIES.json protect libraries absent from the source checkout; whenever
a source copy exists, packaged code must also match it exactly (up to CRLF).
"""
from __future__ import annotations

import argparse
import hashlib
import json
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
    release_seen: set[Path] = set()
    manifest = root / "manifest.xml"
    if not manifest.is_file():
        return ["packaged manifest.xml is missing"]

    # No deferrals here: a release that cannot load its libraries is broken.
    collect(manifest, root, release_seen, problems)
    if problems:
        return problems

    # Collect source-owned references only. Vendor libraries need not exist in
    # source, but if a vendor file does exist, we compare it with the release.
    source_seen: set[Path] = set()
    collect(source / "manifest.xml", source, source_seen, problems, skip_libs=True)
    if problems:
        return problems
    expected: set[Path] = {Path("manifest.xml")}
    for xml in release_seen:
        rel_xml = xml.relative_to(root)
        expected.add(rel_xml)
        for node in ET.parse(xml).getroot().iter():
            if local(node.tag) in ("Include", "Script"):
                raw = node.get("file")
                if raw:
                    expected.add((xml.parent / raw.replace("\\", "/")).resolve().relative_to(root))

    for rel in sorted(expected):
        shipped = root / rel
        original = source / rel
        if not shipped.is_file():
            problems.append(f"packaged file missing: {rel}")
        elif original.is_file() and normalized(shipped.read_bytes()) != normalized(original.read_bytes()):
            problems.append(f"packaged code differs from tested source: {rel}")
        elif not original.is_file() and (not rel.parts or rel.parts[0] != "libs"):
            problems.append(f"non-vendor file missing from tested source: {rel}")

    # Hash-verification remains meaningful even in a clean checkout without
    # libs/. Without this, packaging could fetch a different upstream revision.
    dependencies_file = source / "DEPENDENCIES.json"
    if not dependencies_file.is_file():
        problems.append("DEPENDENCIES.json is missing: cannot verify external libraries")
    else:
        try:
            deps = json.loads(dependencies_file.read_text(encoding="utf-8"))
            entries = deps["libraries"]
            pinned: set[Path] = set()
            for entry in entries:
                rel = Path(entry["path"])
                if rel.is_absolute() or ".." in rel.parts or rel.parts[0] != "libs":
                    problems.append(f"invalid dependency path: {rel}")
                    continue
                pinned.add(rel)
                shipped = root / rel
                if not shipped.is_file():
                    problems.append(f"pinned library missing from package: {rel}")
                    continue
                actual = hashlib.sha256(normalized(shipped.read_bytes())).hexdigest()
                if actual != entry["sha256"]:
                    problems.append(f"library SHA-256 mismatch: {rel}")
            runtime_libs = {p for p in expected if p.parts and p.parts[0] == "libs" and p.suffix == ".lua"}
            for rel in sorted(runtime_libs - pinned):
                problems.append(f"runtime library has no pinned checksum: {rel}")
            for rel in sorted(pinned - runtime_libs):
                problems.append(f"pinned library not loaded by XML manifest: {rel}")
        except (ValueError, KeyError, TypeError, IndexError) as exc:
            problems.append(f"invalid DEPENDENCIES.json: {exc}")

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
    print("package OK: complete load chain, pinned libraries, tested code and release ZIP match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
