#!/usr/bin/env python3
"""Offline regression for tools/check_official_clients.py (no network)."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = "Region!STRING:0|BuildConfig!HEX:16|CDNConfig!HEX:16|KeyRing!HEX:16|BuildId!DEC:4|VersionsName!String:0|ProductConfig!HEX:16"
data = json.loads((ROOT / "tools" / "official_clients.json").read_text(encoding="utf-8"))


def write_fixtures(folder: Path, bump: str | None = None) -> None:
    for product in data["products"]:
        rows = [HEADER, "## seqn = 1"]
        for region in product["regions"]:
            build = product["builds"][region]
            if product["key"] == bump and region == product["regions"][0]:
                build += 1
            rows.append(f"{region.lower()}|aa|bb||{build}|{product['version']}.{build}|cc")
        (folder / f"{product['product']}.psv").write_text("\n".join(rows) + "\n", encoding="utf-8")


def run(folder: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, "-I", str(ROOT / "tools" / "check_official_clients.py"), "--input", str(folder)],
                          capture_output=True, text=True)


with tempfile.TemporaryDirectory(prefix="mcd-clients-") as tmp:
    folder = Path(tmp)
    write_fixtures(folder)
    current = run(folder)
    assert current.returncode == 0, current.stdout + current.stderr
    write_fixtures(folder, bump="retail")
    drift = run(folder)
    assert drift.returncode == 1 and "retail US" in drift.stdout, drift.stdout + drift.stderr
    (folder / "wowf.psv").unlink()
    missing = run(folder)
    assert missing.returncode == 1 and "forever: cannot read" in missing.stdout, missing.stdout

print("probe_official_clients: PASS (current data, build drift, unreadable source)")
