#!/usr/bin/env python3
"""Compare tools/official_clients.json with Blizzard's public version service.

Each product in official_clients.json names its `versions_source`
(https://us.version.battle.net/v2/products/<product>/versions). That endpoint
returns a pipe-separated table with one row per region:

    Region!STRING:0|BuildConfig!HEX:16|CDNConfig!HEX:16|KeyRing!HEX:16|BuildId!DEC:4|VersionsName!String:0|ProductConfig!HEX:16
    ## seqn = 123
    us|...|...||70783|12.1.5.70783|...

The check reports any region whose live version or build differs from the
recorded one. It never edits the JSON: a human updates it together with the
TOC interface numbers (tools/generate_tocs.py).

Usage:
  check_official_clients.py                 fetch live data (CI, weekly)
  check_official_clients.py --input DIR     read DIR/<product>.psv (offline tests)
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def parse_versions(text: str) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    header: list[str] | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("##"):
            continue
        cells = line.split("|")
        if header is None:
            header = [cell.split("!")[0] for cell in cells]
            continue
        row = dict(zip(header, cells))
        region = row.get("Region", "").upper()
        if region:
            rows[region] = row
    return rows


def fetch(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "MaxCameraDistance-CI"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "replace")


def compare(products: list[dict], load) -> list[str]:
    drift: list[str] = []
    for product in products:
        source = product.get("versions_source")
        if not source:
            continue
        try:
            live = parse_versions(load(product))
        except Exception as exc:  # network or parse failure is a failure of the check
            drift.append(f"{product['key']}: cannot read {source}: {exc}")
            continue
        for region in product.get("regions", []):
            row = live.get(region)
            if row is None:
                drift.append(f"{product['key']} {region}: region missing from {source}")
                continue
            expected_build = str(product.get("builds", {}).get(region, ""))
            live_build = row.get("BuildId", "")
            live_version = row.get("VersionsName", "")
            expected_version = f"{product['version']}.{expected_build}"
            if live_build != expected_build or live_version != expected_version:
                drift.append(f"{product['key']} {region}: recorded {expected_version}, live {live_version or '?'}")
    return drift


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, help="directory with <product>.psv files instead of the network")
    parser.add_argument("--clients", type=Path, default=ROOT / "tools" / "official_clients.json")
    args = parser.parse_args()

    data = json.loads(args.clients.read_text(encoding="utf-8"))
    if args.input:
        load = lambda product: (args.input / f"{product['product']}.psv").read_text(encoding="utf-8")
    else:
        load = lambda product: fetch(product["versions_source"])

    drift = compare(data["products"], load)
    if drift:
        print("official_clients.json is out of date (verified " + str(data.get("verified_date")) + "):")
        print("\n".join(" - " + line for line in drift))
        return 1
    print(f"official clients current: {len(data['products'])} products")
    return 0


if __name__ == "__main__":
    sys.exit(main())
