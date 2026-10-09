#!/usr/bin/env python3
"""Validate WoW XML load references, with separate source/release policies.

In a source checkout, ``libs/`` may be populated by the release pipeline *after*
this check. The default source check therefore validates every other reference,
including nested XML manifests, but deliberately defers all ``libs/`` paths.

Use ``--strict-libs`` on the completed addon tree. A missing runtime library in
an actual release is ALWAYS an error; tools/verify_package.py enforces this too.

Usage:
    python3 tools/verify_manifest.py [--root .] [--strict-libs]
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT_MANIFEST = "manifest.xml"
LIBS_DIRECTORY = "libs"
LOCAL_NAME = re.compile(r"\{.*\}")


def local(tag: str) -> str:
    return LOCAL_NAME.sub("", tag)


def collect(
    manifest: Path,
    root: Path,
    seen: set[Path],
    problems: list[str],
    *,
    skip_libs: bool = False,
) -> None:
    """Follow XML Include/Script entries, optionally deferring vendor libraries.

    Skipping applies to the *whole* libs tree (even if files are present), so
    source checks do not change depending on which dependencies happen to have
    been downloaded locally. Paths outside the addon root are never allowed.
    """
    manifest = manifest.resolve()
    root = root.resolve()
    if manifest in seen:
        return
    seen.add(manifest)

    try:
        tree = ET.parse(manifest)
    except (ET.ParseError, OSError) as exc:
        problems.append(f"{manifest.relative_to(root)}: cannot parse XML ({exc})")
        return

    for node in tree.getroot().iter():
        name = local(node.tag)
        if name not in ("Script", "Include"):
            continue
        raw = node.get("file")
        if not raw:
            problems.append(f"{manifest.relative_to(root)}: <{name}> without a file attribute")
            continue

        target = (manifest.parent / raw.replace("\\", "/")).resolve()
        try:
            rel = target.relative_to(root)
        except ValueError:
            problems.append(f"{manifest.relative_to(root)}: '{raw}' escapes the addon folder")
            continue

        if skip_libs and rel.parts and rel.parts[0] == LIBS_DIRECTORY:
            continue
        if not target.is_file():
            problems.append(f"{manifest.relative_to(root)}: missing {rel}")
            continue
        if name == "Include":
            collect(target, root, seen, problems, skip_libs=skip_libs)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--strict-libs", action="store_true", help="Require all libs/ references (use for built release)")
    # Compatibility for CI workflows written before the source/release split.
    parser.add_argument("--allow-missing-externals", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    manifest = root / ROOT_MANIFEST
    if not manifest.is_file():
        print(f"error: {ROOT_MANIFEST} not found in {root}", file=sys.stderr)
        return 1

    problems: list[str] = []
    collect(manifest, root, set(), problems, skip_libs=not args.strict_libs)
    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        print(f"{len(problems)} manifest reference(s) could not be resolved", file=sys.stderr)
        return 1

    if args.strict_libs:
        print("manifest OK (release): every referenced file exists, including libs/")
    else:
        print("manifest OK (source): all non-libs references resolved; libs/ deferred to package verification")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
