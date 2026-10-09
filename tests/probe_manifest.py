#!/usr/bin/env python3
"""Regression checks for deferred libs/ in source and strict release checks."""
import shutil
import sys
import tempfile
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SOURCE / "tools"))
from verify_manifest import collect


def problems(root: Path, strict: bool) -> list[str]:
    found: list[str] = []
    collect(root / "manifest.xml", root, set(), found, skip_libs=not strict)
    return found


with tempfile.TemporaryDirectory(prefix="mcd-manifest-") as tmp:
    root = Path(tmp)
    (root / "manifest.xml").write_text(
        '<Ui><Script file="Core.lua"/><Include file="libs/_manifest.xml"/>\n'
        '<Include file="locale/_manifest.xml"/></Ui>', encoding="utf-8")
    (root / "Core.lua").write_text("-- valid", encoding="utf-8")
    (root / "locale").mkdir()
    (root / "locale/_manifest.xml").write_text('<Ui><Script file="enUS.lua"/></Ui>', encoding="utf-8")
    (root / "locale/enUS.lua").write_text("-- valid", encoding="utf-8")

    assert not problems(root, strict=False), "source check incorrectly requires libs/"
    assert any("libs/_manifest.xml" in p for p in problems(root, strict=True)), "release did not require libs manifest"
    (root / "libs").mkdir()
    (root / "libs/_manifest.xml").write_text('<Ui><Script file="LibStub/LibStub.lua"/></Ui>', encoding="utf-8")
    assert not problems(root, strict=False), "source check traversed libs unexpectedly"
    assert any("libs/LibStub/LibStub.lua" in p for p in problems(root, strict=True)), "release did not require library"
    (root / "libs/LibStub").mkdir()
    (root / "libs/LibStub/LibStub.lua").write_text("-- library", encoding="utf-8")
    assert not problems(root, strict=True), "release rejected valid library"
    (root / "locale/enUS.lua").unlink()
    assert any("locale/enUS.lua" in p for p in problems(root, strict=False)), "source skipped a non-libs failure"
    (root / "locale/enUS.lua").write_text("-- restored", encoding="utf-8")
    (root / "libs/_manifest.xml").write_text('<Ui>', encoding="utf-8")
    assert not problems(root, strict=False), "source attempted to parse late vendor manifest"
    assert any("cannot parse XML" in p for p in problems(root, strict=True)), "release ignored malformed vendor XML"
    (root / "libs/_manifest.xml").write_text('<Ui><Script file="../outside.lua"/></Ui>', encoding="utf-8")
    assert any("missing outside.lua" in p for p in problems(root, strict=True)), "release ignored broken path"
    (root / "libs/_manifest.xml").write_text('<Ui><Script file="../../escape.lua"/></Ui>', encoding="utf-8")
    assert any("escapes the addon folder" in p for p in problems(root, strict=True)), "release allowed escaping path"

print("probe_manifest: PASS (deferred source libs, strict release, XML, path and non-libs regressions)")
