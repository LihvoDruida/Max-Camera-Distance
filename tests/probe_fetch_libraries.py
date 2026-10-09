#!/usr/bin/env python3
"""Offline regression test for missing vendor dependencies in CI checkout."""
import json
import shutil
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SOURCE / "tools"))
from fetch_libraries import verify_and_fetch, upstream_url

entries = json.loads((SOURCE / "DEPENDENCIES.json").read_text(encoding="utf-8"))["libraries"]
url_data = {entry["source"]: (SOURCE / entry["path"]).read_bytes() for entry in entries}
assert "raw.githubusercontent.com" in upstream_url(entries[0]["source"])

with tempfile.TemporaryDirectory(prefix="mcd-fetch-") as tmp:
    root = Path(tmp)
    shutil.copy2(SOURCE / "DEPENDENCIES.json", root / "DEPENDENCIES.json")
    (root / "libs").mkdir()
    shutil.copy2(SOURCE / "libs/_manifest.xml", root / "libs/_manifest.xml")
    camera = root / "libs/LibCamera/LibCamera.lua"
    camera.parent.mkdir(parents=True)
    shutil.copy2(SOURCE / "libs/LibCamera/LibCamera.lua", camera)

    with patch("fetch_libraries.download", side_effect=lambda url: url_data[url]) as fetch:
        assert verify_and_fetch(root) == [], "valid pinned vendor download rejected"
        assert fetch.call_count == 5, "expected exactly five downloaded dependencies"
        assert verify_and_fetch(root) == [], "already installed dependencies rejected"
        assert fetch.call_count == 5, "already installed dependencies downloaded again"

    libstub = root / "libs/LibStub/LibStub.lua"
    libstub.write_text("malicious or outdated copy", encoding="utf-8")
    assert any("SHA-256 mismatch" in error for error in verify_and_fetch(root)), \
        "tampered vendored Lua accepted"
    libstub.unlink()
    camera.unlink()
    assert any("missing locally modified library" in error for error in verify_and_fetch(root) \
               if "LibCamera" in error), "missing private library accepted"

print("probe_fetch_libraries: PASS (offline fetch, checksum, idempotency, private LibCamera)")
