#!/usr/bin/env python3
"""Generate per-flavour .toc files from Max_Camera_Distance.toc.

Max_Camera_Distance.toc is the single source of truth for the Mainline build,
version and all shared metadata. Per-client TOCs are produced from it by
replacing flavour headers and, when required, applying a very small explicit
flavour override (Forever/Camelot needs a load-time marker before manifest.xml).

    python3 tools/generate_tocs.py          # write the files
    python3 tools/generate_tocs.py --check  # verify they are current (CI)
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "Max_Camera_Distance"
SOURCE = ROOT / f"{ADDON}.toc"

# Mainline has no patch-specific TOC suffix, so one source TOC intentionally
# lists the supported live/PTR interface values for the same client flavour.
MAINLINE_INTERFACE = "120007, 120100, 120105"

# suffix -> configuration
# Interface numbers track Warcraft Wiki's current documented client builds.
FLAVOURS = {
    "Camelot": {
        "interface": "16001",
        "flavor": "forever",
        "expansion": "World of Warcraft: Forever",
        "metadata": {
            "Notes": "Smart camera distance with dedicated WoW: Forever compatibility.",
            "Notes-zhCN": "智能镜头距离，提供独立的《魔兽世界：永恒》兼容支持。",
        },
        "extra_files": ("Forever.lua",),
    },
    "Vanilla": {
        "interface": "11509",
        "flavor": "vanilla",
        "expansion": "Classic Era",
    },
    "TBC": {
        "interface": "20506",
        "flavor": "tbc",
        "expansion": "TBC Anniversary",
    },
    "Wrath": {
        "interface": "30405, 38002",
        "flavor": "wrath",
        "expansion": "Wrath / Titan Reforged",
    },
    "Cata": {
        "interface": "40402",
        "flavor": "cata",
        "expansion": "Cataclysm Classic",
    },
    "Mists": {
        "interface": "50504",
        "flavor": "mists",
        "expansion": "Mists of Pandaria Classic",
    },
}

# Files that previously used suffixes the client does not load.
OBSOLETE = [f"{ADDON}-Era.toc", f"{ADDON}-BCC.toc", f"{ADDON}-Mists.toc"]

HEADER = re.compile(r"^## ([^:]+):.*$")
REQUIRED = ("Interface", "X-Flavor", "X-Expansion")


def render(
    source_text: str,
    interface: str,
    flavor: str,
    expansion: str,
    metadata=None,
    extra_files=(),
) -> str:
    """Render one flavour without allowing generated TOCs to drift manually."""
    replacements = {
        "Interface": interface,
        "X-Flavor": flavor,
        "X-Expansion": expansion,
    }
    if metadata:
        replacements.update(metadata)

    seen = set()
    out = []
    for line in source_text.split("\n"):
        match = HEADER.match(line)
        if match:
            key = match.group(1)
            if key in replacements:
                seen.add(key)
                out.append(f"## {key}: {replacements[key]}")
                continue
        out.append(line)

    missing = set(REQUIRED) - seen
    if missing:
        raise SystemExit(
            f"{SOURCE.name} is missing required header(s): {', '.join(sorted(missing))}"
        )

    # Forever/Camelot must set its load-time marker before shared files execute.
    if extra_files:
        try:
            manifest_index = out.index("manifest.xml")
        except ValueError as exc:
            raise SystemExit(f"{SOURCE.name} is missing manifest.xml") from exc
        for filename in reversed(tuple(extra_files)):
            if filename not in out:
                out.insert(manifest_index, filename)

    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if any generated file is missing or stale",
    )
    args = parser.parse_args()

    if not SOURCE.exists():
        raise SystemExit(f"source TOC not found: {SOURCE}")

    source_text = SOURCE.read_text(encoding="utf-8")

    # Keep the source itself honest about its Mainline headers.
    expected_source = render(
        source_text,
        MAINLINE_INTERFACE,
        "mainline",
        "Midnight",
    )
    problems = []

    if expected_source != source_text:
        if args.check:
            problems.append(f"{SOURCE.name} (Mainline headers are stale)")
        else:
            SOURCE.write_text(expected_source, encoding="utf-8")
            print(f"updated  {SOURCE.name}")
        source_text = expected_source

    for suffix, config in sorted(FLAVOURS.items()):
        target = ROOT / f"{ADDON}_{suffix}.toc"
        content = render(
            source_text,
            config["interface"],
            config["flavor"],
            config["expansion"],
            metadata=config.get("metadata"),
            extra_files=config.get("extra_files", ()),
        )

        if args.check:
            if not target.exists() or target.read_text(encoding="utf-8") != content:
                problems.append(target.name)
        else:
            target.write_text(content, encoding="utf-8")
            print(f"wrote    {target.name}  (Interface {config['interface']})")

    for name in OBSOLETE:
        stale = ROOT / name
        if stale.exists():
            if args.check:
                problems.append(f"{name} (obsolete dash suffix - delete it)")
            else:
                stale.unlink()
                print(f"removed  {name}  (obsolete dash suffix)")

    if problems:
        print("Stale or missing TOC files:", file=sys.stderr)
        for name in problems:
            print(f"  - {name}", file=sys.stderr)
        print("Run: python3 tools/generate_tocs.py", file=sys.stderr)
        return 1

    if args.check:
        print("All .toc files are up to date.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
