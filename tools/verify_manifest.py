#!/usr/bin/env python3
"""Verify that every file referenced by the addon's XML manifests exists.

A <Script>/<Include> pointing at a missing file does not stop WoW from loading
the addon. It logs a line nobody reads and carries on with a library silently
absent, which is exactly how "Max_Camera_Distance isn't registered with
AceConfigRegistry" reached users: the options table was never built because
AceConfig-3.0 was never loaded.

Run this AFTER the packager has fetched .pkgmeta externals (so libs/ is
populated). Before that point the external folders legitimately do not exist,
so --allow-missing-externals downgrades those specific paths to warnings.

Usage:
    python3 tools/verify_manifest.py [--root .] [--allow-missing-externals]
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT_MANIFEST = "manifest.xml"
EXTERNAL_PREFIX = "libs/"

# <Ui xmlns="..."> means every tag comes back namespaced; match on the local name.
LOCAL_NAME = re.compile(r"\{.*\}")


def local(tag: str) -> str:
    return LOCAL_NAME.sub("", tag)


def strip_no_lib(text: str) -> str:
    """The packager may remove @no-lib-strip@ blocks; we always keep them."""
    return text


def collect(manifest: Path, root: Path, seen: set[Path], problems: list[str]) -> None:
    if manifest in seen:
        return
    seen.add(manifest)

    try:
        tree = ET.parse(manifest)
    except ET.ParseError as exc:
        problems.append(f"{manifest.relative_to(root)}: malformed XML ({exc})")
        return

    base = manifest.parent

    for node in tree.getroot().iter():
        name = local(node.tag)
        if name not in ("Script", "Include"):
            continue

        raw = node.get("file")
        if not raw:
            problems.append(f"{manifest.relative_to(root)}: <{name}> without a file attribute")
            continue

        target = base / Path(raw.replace("\\", "/"))
        try:
            rel = target.resolve().relative_to(root.resolve())
        except ValueError:
            problems.append(f"{manifest.relative_to(root)}: '{raw}' escapes the addon folder")
            continue

        if not target.is_file():
            problems.append(f"{manifest.relative_to(root)}: missing {rel}")
            continue

        if name == "Include":
            collect(target, root, seen, problems)


def is_external(problem: str) -> bool:
    return f"missing {EXTERNAL_PREFIX}" in problem


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--allow-missing-externals", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    manifest = root / ROOT_MANIFEST

    if not manifest.is_file():
        print(f"error: {ROOT_MANIFEST} not found in {root}", file=sys.stderr)
        return 1

    problems: list[str] = []
    collect(manifest, root, set(), problems)

    fatal = [p for p in problems if not (args.allow_missing_externals and is_external(p))]
    warnings = [p for p in problems if p not in fatal]

    for warning in warnings:
        print(f"warning: {warning} (external, not fetched yet)")

    if fatal:
        for problem in fatal:
            print(f"error: {problem}", file=sys.stderr)
        print(
            f"\n{len(fatal)} manifest reference(s) could not be resolved. "
            "A library that is referenced but absent loads as nil and produces "
            "a silent, character-dependent failure at runtime.",
            file=sys.stderr,
        )
        return 1

    if warnings:
        print(f"manifest OK: {len(warnings)} external reference(s) skipped, everything else resolved")
    else:
        print("manifest OK: every referenced file exists")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
