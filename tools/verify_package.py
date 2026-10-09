#!/usr/bin/env python3
"""Validate the packager-built addon tree and its ZIP (not an earlier library checkout).

The five .pkgmeta external libraries are fetched by BigWigsMods/packager.
They are intentionally NOT compared with unrelated sources or hash pins.
Source-owned Lua/XML must match the source checkout, while all finished Lua
references and *every byte* of the built ZIP must match the verified package.
"""
from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from verify_manifest import collect, local


def normalized(data: bytes) -> bytes:
    """Packager is allowed to normalize text file line endings."""
    return data.replace(b"\r\n", b"\n")


def declared_externals(source: Path) -> set[Path]:
    """Read only the destination keys of the .pkgmeta `externals` section.

    Restrict directories to libs/<one-name>; never ignore an entire libs tree.
    PyYAML is intentionally not required in CI.
    """
    pkgmeta = source / '.pkgmeta'
    if not pkgmeta.is_file():
        raise ValueError('.pkgmeta is missing')
    externals: set[Path] = set()
    active = False
    for line in pkgmeta.read_text(encoding='utf-8-sig').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line[0].isspace():
            active = line.strip() == 'externals:'
            continue
        if active:
            match = re.fullmatch(r'  ([A-Za-z0-9_.\-/]+):\s*', line)
            if match:
                rel = Path(match.group(1))
                if len(rel.parts) != 2 or rel.parts[0] != 'libs' or rel.parts[1] in ('.', '..'):
                    raise ValueError(f'invalid external directory: {rel}')
                externals.add(rel)
    if not externals:
        raise ValueError('no externals configured in .pkgmeta')
    return externals


def external_file(rel: Path, externals: set[Path]) -> bool:
    return any(ext in rel.parents for ext in externals)


def verify(root: Path, source: Path, archive: Path) -> list[str]:
    root = root.resolve()
    source = source.resolve()
    problems: list[str] = []

    if not (root / 'manifest.xml').is_file():
        return ['packaged manifest.xml is missing']
    if not (source / 'manifest.xml').is_file():
        return ['source manifest.xml is missing']

    try:
        externals = declared_externals(source)
    except (OSError, ValueError) as exc:
        return [f'cannot read external configuration: {exc}']

    # Completed release: all XML script/include references must resolve.
    release_seen: set[Path] = set()
    collect(root / 'manifest.xml', root, release_seen, problems)
    if problems:
        return problems

    # The source tree need not contain .pkgmeta externals. Validate everything
    # else; in particular, LibCamera is PRIVATE code tracked by this project.
    source_seen: set[Path] = set()
    # Support both verifier APIs used in this project while transitioning
    # from the earlier `allow_missing_externals` flag to `skip_libs`.
    try:
        collect(source / 'manifest.xml', source, source_seen, problems, skip_libs=True)
    except TypeError as exc:
        if 'skip_libs' not in str(exc):
            raise
        collect(source / 'manifest.xml', source, source_seen, problems,
                allow_missing_externals=True)
    if problems:
        return problems

    expected: set[Path] = {Path('manifest.xml')}
    for xml in release_seen:
        try:
            expected.add(xml.relative_to(root))
            for node in ET.parse(xml).getroot().iter():
                if local(node.tag) not in ('Include', 'Script'):
                    continue
                raw = node.get('file')
                if raw:
                    expected.add((xml.parent / raw.replace('\\', '/')).resolve().relative_to(root))
        except (ValueError, ET.ParseError) as exc:
            problems.append(f'invalid release manifest reference: {exc}')
    if problems:
        return problems

    loaded_external: set[Path] = set()
    for rel in sorted(expected):
        shipped = root / rel
        owned = source / rel
        if not shipped.is_file():
            problems.append(f'packaged file missing: {rel.as_posix()}')
            continue
        if shipped.stat().st_size == 0:
            problems.append(f'packaged file is empty: {rel.as_posix()}')
            continue

        if external_file(rel, externals):
            # Do NOT compare BigWigs releases to local vendor copies or to
            # DEPENDENCIES.json SHA-256 from unrelated upstream revisions.
            loaded_external.update(ext for ext in externals if ext in rel.parents)
            continue

        if not owned.is_file():
            problems.append(f'source-owned runtime file missing from checkout: {rel.as_posix()}')
        elif normalized(shipped.read_bytes()) != normalized(owned.read_bytes()):
            problems.append(f'packaged code differs from tested source: {rel.as_posix()}')

    for ext in sorted(externals - loaded_external):
        problems.append(f'configured external absent from loaded XML or release: {ext.as_posix()}')

    if not archive.is_file() or archive.suffix.lower() != '.zip':
        problems.append(f'packaged archive is missing or not a ZIP file: {archive}')
        return problems
    try:
        with zipfile.ZipFile(archive) as z:
            damaged = z.testzip()
            if damaged is not None:
                problems.append(f'release ZIP has a damaged entry: {damaged}')
            names = z.namelist()
            if len(names) != len(set(names)):
                problems.append('release ZIP has duplicate entries')
            files = {root.name + '/' + p.relative_to(root).as_posix(): p
                     for p in root.rglob('*') if p.is_file()}
            zipped = {n for n in names if not n.endswith('/')}
            for name in sorted(set(files) - zipped):
                problems.append(f'release ZIP is missing {name}')
            for name in sorted(zipped - set(files)):
                problems.append(f'release ZIP contains an unexpected file: {name}')
            for name in sorted(set(files) & zipped):
                if z.read(name) != files[name].read_bytes():
                    problems.append(f'release ZIP differs from packaged folder: {name}')
    except (OSError, zipfile.BadZipFile) as exc:
        problems.append(f'cannot verify release ZIP: {exc}')

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--archive', required=True, type=Path)
    args = parser.parse_args()
    problems = verify(args.root, Path(__file__).resolve().parent.parent, args.archive)
    for problem in problems:
        print(f'error: {problem}', file=sys.stderr)
    if problems:
        return 1
    print('package OK: .pkgmeta externals are complete, source-owned code and ZIP match the release')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
