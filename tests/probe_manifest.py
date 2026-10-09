#!/usr/bin/env python3
"""Offline regression for source-only .pkgmeta externals and strict package XML."""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
from verify_manifest import collect, external_dirs

with tempfile.TemporaryDirectory(prefix='mcd-manifest-') as temp:
    source = Path(temp)
    (source / '.pkgmeta').write_text('''package-as: Max_Camera_Distance
externals:
  libs/LibStub:
    url: https://example.invalid/vendor
    tag: latest
''', encoding='utf-8')
    (source / 'manifest.xml').write_text('''<Ui><Script file="Core.lua"/><Include file="libs/_manifest.xml"/><Include file="locale/_manifest.xml"/></Ui>''', encoding='utf-8')
    (source / 'Core.lua').write_text('-- core', encoding='utf-8')
    (source / 'libs').mkdir()
    (source / 'libs/_manifest.xml').write_text('''<Ui><Script file="LibStub/LibStub.lua"/><Script file="LibCamera/LibCamera.lua"/></Ui>''', encoding='utf-8')
    (source / 'libs/LibCamera').mkdir()
    (source / 'libs/LibCamera/LibCamera.lua').write_text('-- owned', encoding='utf-8')
    (source / 'locale').mkdir()
    (source / 'locale/_manifest.xml').write_text('<Ui><Script file="enUS.lua"/></Ui>', encoding='utf-8')
    (source / 'locale/enUS.lua').write_text('-- enUS', encoding='utf-8')

    def problems(deferred: bool) -> list[str]:
        errors: list[str] = []
        collect(source / 'manifest.xml', source, set(), errors, allow_missing_externals=deferred)
        return errors

    assert external_dirs(source) == {Path('libs/LibStub')}
    assert problems(True) == [], 'declared missing vendor library must be deferred in source'
    assert any('LibStub/LibStub.lua' in p for p in problems(False)), 'strict manifest accepted missing vendor'
    (source / 'libs/LibCamera/LibCamera.lua').unlink()
    assert any('LibCamera/LibCamera.lua' in p for p in problems(True)), 'private library incorrectly deferred'
    (source / 'libs/LibCamera/LibCamera.lua').write_text('-- restored', encoding='utf-8')
    (source / 'locale/enUS.lua').unlink()
    assert any('locale/enUS.lua' in p for p in problems(True)), 'non-vendor locale incorrectly deferred'
    (source / 'locale/enUS.lua').write_text('-- restored', encoding='utf-8')
    (source / 'libs/_manifest.xml').write_text('<Ui><Script file="LibStub/LibStub.lua"/></Ui>', encoding='utf-8')
    assert problems(True) == [], 'allowed external incorrectly rejected'
    (source / 'libs/_manifest.xml').write_text('<Ui><Script file="../../escape.lua"/></Ui>', encoding='utf-8')
    assert any('escapes the addon folder' in p for p in problems(True)), 'path traversal incorrectly allowed'
    (source / 'libs/_manifest.xml').write_text('<Ui>', encoding='utf-8')
    assert any('cannot read XML' in p for p in problems(True)), 'malformed XML incorrectly allowed'

print('probe_manifest: PASS (deferred .pkgmeta externals, private LibCamera, locale, paths, malformed XML)')
