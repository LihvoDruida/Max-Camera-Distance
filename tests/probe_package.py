#!/usr/bin/env python3
"""Offline tests for BigWigs-provided externals and archive integrity."""
from __future__ import annotations

import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SOURCE / 'tools'))
from verify_package import declared_externals, verify


def check_message(issues: list[str], needle: str) -> None:
    assert any(needle in issue for issue in issues), f'expected {needle!r}, got {issues}'


with tempfile.TemporaryDirectory(prefix='mcd-package-') as tmp:
    base = Path(tmp)
    release = base / 'Max_Camera_Distance'
    shutil.copytree(SOURCE, release, ignore=shutil.ignore_patterns(
        '.git', '.release', '__pycache__'))
    archive = base / 'Max_Camera_Distance-vTEST.zip'
    externals = declared_externals(SOURCE)
    assert len(externals) == 5, f'expected five externally downloaded libraries, got {externals}'

    # BigWigs fetches arbitrary upstream bytes into the *release* folder.
    # The source tree is never populated in this test.
    for ext in externals:
        file = release / ext / (ext.name + '.lua')
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(b'-- retrieved by the release packager\n')

    def package() -> None:
        with zipfile.ZipFile(archive, 'w') as z:
            for file in sorted(release.rglob('*')):
                if file.is_file():
                    z.write(file, file.relative_to(base).as_posix())

    package()
    assert verify(release, SOURCE, archive) == [], 'valid .pkgmeta externally populated package rejected'

    # Local vendor copies may be from a different branch/tag and must not be
    # treated as the source of truth for files BigWigs downloads.
    local_vendor_source = base / 'source-with-stale-vendor'
    shutil.copytree(SOURCE, local_vendor_source, ignore=shutil.ignore_patterns(
        '.git', '.release', '__pycache__'))
    stale_file = local_vendor_source / 'libs/LibStub/LibStub.lua'
    stale_file.parent.mkdir(parents=True, exist_ok=True)
    stale_file.write_bytes(b'-- unrelated earlier upstream revision\n')
    assert verify(release, local_vendor_source, archive) == [], 'package incorrectly compared packager externals to stale checkout'

    # Different, nonempty packager-fetched library content is acceptable, but
    # must always be identical to the bytes in the actual resulting ZIP.
    actual_vendor = release / 'libs/AceDB-3.0/AceDB-3.0.lua'
    actual_vendor.write_bytes(b'-- a newer upstream tag of AceDB\n')
    package()
    assert verify(release, SOURCE, archive) == [], 'valid new tag of external rejected'

    vendor = release / 'libs/LibStub/LibStub.lua'
    original = vendor.read_bytes()
    vendor.unlink()
    check_message(verify(release, SOURCE, archive), 'missing libs/LibStub')
    vendor.write_bytes(b'')
    package()
    check_message(verify(release, SOURCE, archive), 'empty: libs/LibStub')
    vendor.write_bytes(original)

    camera = release / 'libs/LibCamera/LibCamera.lua'
    camera_original = camera.read_bytes()
    camera.write_bytes(camera_original + b'\n-- injected change\n')
    package()
    check_message(verify(release, SOURCE, archive), 'differs from tested source: libs/LibCamera')
    camera.write_bytes(camera_original.replace(b'\n', b'\r\n'))
    package()
    assert verify(release, SOURCE, archive) == [], 'CRLF-normalized source-owned code rejected'
    camera.write_bytes(camera_original)

    package()
    vendor.write_bytes(b'-- changed after packaging\n')
    check_message(verify(release, SOURCE, archive), 'release ZIP differs')
    vendor.write_bytes(original)
    package()
    with zipfile.ZipFile(archive, 'a') as z:
        z.writestr('Max_Camera_Distance/extra/unauthorized.lua', '-- unexpected')
    check_message(verify(release, SOURCE, archive), 'unexpected file')
    check_message(verify(release, SOURCE, base), 'not a ZIP file')
    check_message(verify(release, SOURCE, base / 'missing.zip'), 'not a ZIP file')

print('probe_package: PASS (externals, stale source, updated tags, missing/empty, private camera, ZIP, CRLF)')
