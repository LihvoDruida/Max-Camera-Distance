#!/usr/bin/env python3
"""Generate the per-flavour .toc files from Max_Camera_Distance.toc.

Max_Camera_Distance.toc is the single source of truth: it carries the Mainline
build, the file list, the version and all shared metadata. Every other .toc is
produced from it by swapping exactly three headers - Interface, X-Flavor and
X-Expansion - and nothing else.

    python3 tools/generate_tocs.py          # write the files
    python3 tools/generate_tocs.py --check  # verify they are current (CI)

Naming
------
The client looks for AddonName_<Flavour>.toc and falls back to AddonName.toc
when no suffix matches. The separator is an UNDERSCORE.

The only dash forms the client ever recognised were the two legacy suffixes
-WOTLKC and -BCC, and Patch 2.5.5 (2026-01-13) dropped -BCC as well. The files
this script replaces were named -Era, -BCC and -Mists, so:

  * -Era and -Mists were never valid suffixes on any client, and
  * -BCC stopped loading on the Anniversary client in January 2026.

All three Classic flavours were therefore falling through to the Mainline
Max_Camera_Distance.toc and reporting the addon as out of date - which is also
how those files drifted to stale interface numbers (11508 / 20505 / 50503)
without anyone noticing.

Reference: https://warcraft.wiki.gg/wiki/TOC_format
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "Max_Camera_Distance"
SOURCE = ROOT / f"{ADDON}.toc"

# The Mainline TOC lists two interface versions: 12.0.7 is live and 12.1.0 is on
# the PTR. There is no TOC suffix that distinguishes patch levels within one
# flavour, so a comma-delimited Interface is the only way to be current on both.
# This is still one flavour per file - not a single multi-flavour TOC.
MAINLINE_INTERFACE = "120007, 120100"

# suffix -> (Interface, X-Flavor, X-Expansion)
#
# Interface numbers track Template:API_LatestInterface on Warcraft Wiki.
# _Wrath covers both Wrath Classic and Titan Reforged, hence two versions there.
FLAVOURS = {
    "Vanilla": ("11509", "vanilla", "Classic Era"),
    "TBC": ("20506", "tbc", "TBC Anniversary"),
    "Wrath": ("30405, 38002", "wrath", "Wrath / Titan Reforged"),
    "Cata": ("40402", "cata", "Cataclysm Classic"),
    "Mists": ("50504", "mists", "Mists of Pandaria Classic"),
}

# Files that previously tried to do this job under names the client never loads.
OBSOLETE = [f"{ADDON}-Era.toc", f"{ADDON}-BCC.toc", f"{ADDON}-Mists.toc"]

HEADER = re.compile(r"^## (Interface|X-Flavor|X-Expansion):.*$")


def render(source_text: str, interface: str, flavor: str, expansion: str) -> str:
    """Return source_text with only the three flavour headers replaced."""
    replacements = {
        "Interface": interface,
        "X-Flavor": flavor,
        "X-Expansion": expansion,
    }
    seen = set()
    out = []

    for line in source_text.split("\n"):
        match = HEADER.match(line)
        if match:
            key = match.group(1)
            seen.add(key)
            out.append(f"## {key}: {replacements[key]}")
        else:
            out.append(line)

    missing = set(replacements) - seen
    if missing:
        raise SystemExit(
            f"{SOURCE.name} is missing required header(s): {', '.join(sorted(missing))}"
        )

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

    # Keep the source itself honest about its own interface version.
    expected_source = render(source_text, MAINLINE_INTERFACE, "mainline", "Midnight")
    problems = []

    if expected_source != source_text:
        if args.check:
            problems.append(f"{SOURCE.name} (Mainline headers are stale)")
        else:
            SOURCE.write_text(expected_source, encoding="utf-8")
            print(f"updated  {SOURCE.name}")
        source_text = expected_source

    for suffix, (interface, flavor, expansion) in sorted(FLAVOURS.items()):
        target = ROOT / f"{ADDON}_{suffix}.toc"
        content = render(source_text, interface, flavor, expansion)

        if args.check:
            if not target.exists() or target.read_text(encoding="utf-8") != content:
                problems.append(target.name)
        else:
            target.write_text(content, encoding="utf-8")
            print(f"wrote    {target.name}  (Interface {interface})")

    for name in OBSOLETE:
        stale = ROOT / name
        if stale.exists():
            if args.check:
                problems.append(f"{name} (dash suffix, never loads - delete it)")
            else:
                stale.unlink()
                print(f"removed  {name}  (dash suffix is not loadable)")

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
