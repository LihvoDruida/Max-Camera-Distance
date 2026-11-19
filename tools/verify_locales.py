#!/usr/bin/env python3
"""Locale gate.

Fails when:
  * a key the code reads literally (L["KEY"] or L.KEY) is missing from enUS,
    because ns.Locale:Get returns the raw key name in that case;
  * a shipped locale lacks an enUS key (the player would see English text);
  * a shipped locale defines a key enUS does not (a stale translation).

Keys built at runtime (for example L["PERF_" .. key:upper()]) are invisible to
the literal scan; their enUS entries are never reported as unused, because
this gate does not report unused keys at all.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES = ["enUS", "ukUA", "deDE", "frFR", "zhCN"]
KEY_DEF = re.compile(r'^L\["([A-Z0-9_]+)"\]\s*=', re.M)
KEY_USE = re.compile(r'\bL\["([A-Z0-9_]+)"\]|\bL\.([A-Z][A-Z0-9_]+)\b')


def defined(locale: str) -> set[str]:
    return set(KEY_DEF.findall((ROOT / "locale" / f"{locale}.lua").read_text(encoding="utf-8")))


def used() -> set[str]:
    keys: set[str] = set()
    for path in ROOT.glob("*.lua"):
        for a, b in KEY_USE.findall(path.read_text(encoding="utf-8")):
            keys.add(a or b)
    return keys


def main() -> int:
    en = defined("enUS")
    problems: list[str] = []
    missing_en = sorted(used() - en)
    if missing_en:
        problems.append("used by code but missing in enUS: " + ", ".join(missing_en))
    for locale in LOCALES[1:]:
        keys = defined(locale)
        missing = sorted(en - keys)
        stale = sorted(keys - en)
        if missing:
            problems.append(f"{locale}: {len(missing)} missing: " + ", ".join(missing[:12]) + (" ..." if len(missing) > 12 else ""))
        if stale:
            problems.append(f"{locale}: {len(stale)} not in enUS: " + ", ".join(stale[:12]))
    if problems:
        print("\n".join(problems))
        return 1
    print(f"locales ok: {len(en)} enUS keys, {len(LOCALES) - 1} translations complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
