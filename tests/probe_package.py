#!/usr/bin/env python3
"""Packaging regressions from the missing-library CI failure."""
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SOURCE / "tools"))
from verify_package import verify


with tempfile.TemporaryDirectory(prefix="mcd-package-") as temp:
    root = Path(temp) / "Max_Camera_Distance"
    shutil.copytree(SOURCE, root, ignore=shutil.ignore_patterns(
        ".git", ".release", "__pycache__"))
    archive = Path(temp) / "release.zip"

    def rebuild_zip():
        with zipfile.ZipFile(archive, "w") as z:
            for p in sorted(root.rglob("*")):
                if p.is_file():
                    z.write(p, str(p.relative_to(root.parent)))

    rebuild_zip()
    assert verify(root, SOURCE, archive) == [], "valid package rejected"
    libstub = root / "libs/LibStub/LibStub.lua"
    original = libstub.read_bytes()
    libstub.unlink()
    assert any("missing libs/LibStub" in p for p in verify(root, SOURCE, archive))
    libstub.write_bytes(original)

    camera = root / "libs/LibCamera/LibCamera.lua"
    camera_original = camera.read_bytes()
    camera.write_bytes(camera_original.replace(b"MaxCameraDistance-LibCamera-1.0", b"LibCamera-1.0"))
    rebuild_zip()
    assert any("differs from tested source: libs/LibCamera" in p
               for p in verify(root, SOURCE, archive)), "stale camera accepted"
    camera.write_bytes(camera_original)
    rebuild_zip()
    libstub.write_bytes(original.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
    rebuild_zip()
    assert verify(root, SOURCE, archive) == [], "CRLF package rejected"
    camera.write_bytes(camera_original + b"\n-- stale ZIP regression\n")
    assert any("release ZIP differs" in p for p in verify(root, SOURCE, archive))
    camera.write_bytes(camera_original)
    rebuild_zip()
    with zipfile.ZipFile(archive, "a") as z:
        z.writestr("Max_Camera_Distance/libs/LibMountInfo/LibMountInfo.lua", "stale")
    assert any("unexpected file" in p for p in verify(root, SOURCE, archive))
    assert verify(root, SOURCE, Path(temp) / "missing.zip"), "missing ZIP accepted"

print("probe_package: PASS (missing libraries, stale private camera, CRLF, stale ZIP, extra files)")
