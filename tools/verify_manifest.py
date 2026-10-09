#!/usr/bin/env python3
"""Validate XML load order. Missing .pkgmeta externals are allowed ONLY in source.

Source:  python3 tools/verify_manifest.py --allow-missing-externals
Release: python3 tools/verify_manifest.py --root .release/Max_Camera_Distance

The BigWigs packager fetches .pkgmeta externals into the release folder.
"""
from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT_MANIFEST = 'manifest.xml'
LOCAL_NAME = re.compile(r'\{.*\}')


def local(tag: str) -> str:
    return LOCAL_NAME.sub('', tag)


def external_dirs(root: Path) -> set[Path]:
    """Read external destination directories in .pkgmeta without PyYAML.

    Only two-space-indented keys under the top-level `externals:` map count.
    This is deliberately narrower than ignoring everything under libs/.
    """
    pkgmeta = root / '.pkgmeta'
    if not pkgmeta.is_file():
        return set()
    result: set[Path] = set()
    in_externals = False
    for line in pkgmeta.read_text(encoding='utf-8-sig').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line.startswith((' ', '\t')):
            in_externals = line.strip() == 'externals:'
            continue
        if in_externals:
            match = re.match(r'^  ([\w./-]+):\s*$', line)
            if match:
                candidate = Path(match.group(1))
                # Reject traversal and externals outside addon libs.
                if len(candidate.parts) == 2 and candidate.parts[0] == 'libs' and candidate.parts[1] not in ('.', '..'):
                    result.add(candidate)
    return result


def is_external_file(rel: Path, dirs: set[Path]) -> bool:
    return any(parent == rel or parent in rel.parents for parent in dirs)


def collect(manifest: Path, root: Path, seen: set[Path], problems: list[str],
            *, allow_missing_externals: bool = False, externals: set[Path] | None = None,
            warnings: list[str] | None = None) -> None:
    root = root.resolve()
    manifest = manifest.resolve()
    if externals is None:
        externals = external_dirs(root) if allow_missing_externals else set()
    if manifest in seen:
        return
    seen.add(manifest)
    try:
        tree = ET.parse(manifest)
    except (OSError, ET.ParseError) as exc:
        problems.append(f'{manifest.relative_to(root)}: cannot read XML ({exc})')
        return

    for node in tree.getroot().iter():
        name = local(node.tag)
        if name not in ('Script', 'Include'):
            continue
        raw = node.get('file')
        if not raw:
            problems.append(f'{manifest.relative_to(root)}: <{name}> without a file attribute')
            continue
        target = (manifest.parent / raw.replace('\\', '/')).resolve()
        try:
            rel = target.relative_to(root)
        except ValueError:
            problems.append(f'{manifest.relative_to(root)}: {raw!r} escapes the addon folder')
            continue
        if not target.is_file():
            problem = f'{manifest.relative_to(root)}: missing {rel.as_posix()}'
            if allow_missing_externals and name == 'Script' and is_external_file(rel, externals):
                if warnings is not None:
                    warnings.append(problem)
            else:
                problems.append(problem)
            continue
        if name == 'Include':
            collect(target, root, seen, problems,
                    allow_missing_externals=allow_missing_externals,
                    externals=externals, warnings=warnings)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='.')
    parser.add_argument('--allow-missing-externals', action='store_true')
    args = parser.parse_args()
    root = Path(args.root).resolve()
    if not (root / ROOT_MANIFEST).is_file():
        print(f'error: {ROOT_MANIFEST} not found in {root}', file=sys.stderr)
        return 1
    problems: list[str] = []
    warnings: list[str] = []
    collect(root / ROOT_MANIFEST, root, set(), problems,
            allow_missing_externals=args.allow_missing_externals, warnings=warnings)
    for warning in warnings:
        print(f'warning: {warning} (fetched by packager later)')
    for problem in problems:
        print(f'error: {problem}', file=sys.stderr)
    if problems:
        print(f'manifest FAIL: {len(problems)} invalid/missing reference(s)', file=sys.stderr)
        return 1
    print(f'manifest OK: {len(warnings)} declared external(s) pending' if warnings
          else 'manifest OK: every referenced file exists')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
