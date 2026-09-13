#!/usr/bin/env python3
"""Publish versioned kiosk UI assets into the Flutter web public directory."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SOURCE = REPOSITORY_ROOT / "init-kiosk" / "web"
TARGETS = (
    REPOSITORY_ROOT / "init-app" / "web" / "kiosk",
    REPOSITORY_ROOT / "init-app" / "build" / "web" / "kiosk",
)
VERSION_INPUTS = ("index.html", "app.css", "app.js")
PUBLISHED_ASSETS = (*VERSION_INPUTS, "version.js")


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    version_hash = hashlib.sha256()
    for name in VERSION_INPUTS:
        version_hash.update(name.encode("utf-8"))
        version_hash.update(b"\0")
        version_hash.update((SOURCE / name).read_bytes())
    version = version_hash.hexdigest()[:16]

    version_file = SOURCE / "version.js"
    version_file.write_text(
        f'window.GBOU_KIOSK_UI_VERSION = "{version}";\n',
        encoding="utf-8",
        newline="\n",
    )

    files: dict[str, dict[str, int | str]] = {}
    for name in PUBLISHED_ASSETS:
        source = SOURCE / name
        files[name] = {
            "sha256": _digest(source),
            "size": source.stat().st_size,
        }

    manifest = {"version": version, "files": files}
    for target in TARGETS:
        target.mkdir(parents=True, exist_ok=True)
        for name in PUBLISHED_ASSETS:
            shutil.copyfile(SOURCE / name, target / name)
        (target / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    print(f"Published kiosk UI {version} to {len(TARGETS)} web directories")


if __name__ == "__main__":
    main()
