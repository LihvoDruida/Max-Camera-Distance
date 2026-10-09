#!/usr/bin/env python3
"""Restore the pinned addon libraries after the source-only manifest check.

Missing upstream files are fetched once during CI (never from within WoW).
The locally modified LibCamera is *not* available upstream and must be tracked
with the addon. All downloaded and already-present Lua files are SHA-256
verified against DEPENDENCIES.json before regression probes run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit


def normalized(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def upstream_url(source: str) -> str:
    """Convert the github.com blob URLs documented in DEPENDENCIES.json."""
    parsed = urlsplit(source)
    if parsed.netloc.lower() == "github.com":
        pieces = parsed.path.strip("/").split("/")
        if len(pieces) < 5 or pieces[2] != "blob":
            raise ValueError(f"not a GitHub blob URL: {source}")
        owner, repo, _, branch, *file_parts = pieces
        return f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{'/'.join(file_parts)}"
    if parsed.scheme != "https":
        raise ValueError(f"unsafe dependency source URL: {source}")
    return source


def download(source: str) -> bytes:
    if source.startswith("https://repos.wowace.com/") or source.startswith("https://repos.curseforge.com/"):
        # SVN source servers expose files via `svn cat`, not as raw HTTPS files.
        try:
            proc = subprocess.run(["svn", "cat", source], stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, check=True, timeout=45)
        except (subprocess.CalledProcessError, OSError, subprocess.TimeoutExpired) as exc:
            raise RuntimeError(f"SVN fetch failed for {source}: {exc}") from exc
        return proc.stdout
    url = upstream_url(source)
    request = urllib.request.Request(url, headers={"User-Agent": "MaxCameraDistance-CI/11.1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def verify_and_fetch(root: Path) -> list[str]:
    issues: list[str] = []
    dependencies = json.loads((root / "DEPENDENCIES.json").read_text(encoding="utf-8"))["libraries"]
    for entry in dependencies:
        rel = Path(entry["path"])
        if rel.is_absolute() or ".." in rel.parts or rel.parts[0] != "libs":
            issues.append(f"invalid library path: {rel}")
            continue
        destination = root / rel
        if destination.is_file():
            data = destination.read_bytes()
        else:
            if rel.as_posix() == "libs/LibCamera/LibCamera.lua":
                issues.append(f"missing locally modified library: {rel}; commit it to the repository")
                continue
            try:
                print(f"Fetching pinned library: {rel}", flush=True)
                data = download(entry["source"])
            except (RuntimeError, ValueError, urllib.error.URLError, TimeoutError, OSError) as exc:
                issues.append(f"could not fetch {rel}: {exc}")
                continue
        sha = hashlib.sha256(normalized(data)).hexdigest()
        if sha != entry["sha256"]:
            issues.append(f"SHA-256 mismatch for {rel}: expected {entry['sha256']}, got {sha}")
            continue
        if not destination.is_file():
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
    if not (root / "libs/_manifest.xml").is_file():
        issues.append("libs/_manifest.xml missing; this addon's manifest must be tracked")
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    try:
        problems = verify_and_fetch(Path(args.root).resolve())
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"error: cannot load DEPENDENCIES.json: {exc}", file=sys.stderr)
        return 1
    if problems:
        for issue in problems:
            print("error: " + issue, file=sys.stderr)
        return 1
    print("runtime libraries OK: all dependency files exist and match pinned SHA-256")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
