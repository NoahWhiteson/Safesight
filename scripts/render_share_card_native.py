#!/usr/bin/env python3
"""Render share cards using the real iOS ScanShareExporter (simulator CLI)."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "tools" / "ShareExportCLI" / ".build" / "share-export"
BUILD_SH = ROOT / "scripts" / "native_share_export.sh"
LOGO = ROOT / "Safesight" / "Assets.xcassets" / "AppLogo.imageset" / "AppLogo.png"


def ensure_binary() -> Path:
    if BIN.exists():
        return BIN
    # Build only (don't run) — invoke the compile half of native_share_export.sh
    sdk = subprocess.check_output(
        ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True
    ).strip()
    BIN.parent.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        [
            "xcrun",
            "--sdk",
            "iphonesimulator",
            "swiftc",
            "-parse-as-library",
            "-O",
            "-sdk",
            sdk,
            "-target",
            "arm64-apple-ios17.0-simulator",
            "-D",
            "SHARE_EXPORT_CLI",
            str(ROOT / "tools" / "ShareExportCLI" / "Models.swift"),
            str(ROOT / "Safesight" / "ScanShareExporter.swift"),
            str(ROOT / "tools" / "ShareExportCLI" / "main.swift"),
            "-o",
            str(BIN),
        ]
    )
    return BIN


def booted_iphone_udid() -> str:
    out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "booted"], text=True)
    for line in out.splitlines():
        if "iPhone" in line and "(" in line:
            return line.split("(")[1].split(")")[0]
    # Boot one
    avail = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available"], text=True
    )
    udid = None
    for line in avail.splitlines():
        if "iPhone" in line and "(" in line and "unavailable" not in line.lower():
            udid = line.split("(")[1].split(")")[0]
            if "iPhone 1" in line:
                break
    if not udid:
        raise SystemExit("No iPhone simulator available for native share export")
    subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
    subprocess.check_call(["xcrun", "simctl", "bootstatus", udid, "-b"])
    return udid


def render_share_card_native(photo_path: Path, result: dict, out_path: Path) -> Path:
    """Call ScanShareExporter via simulator; write JPEG (lossy of the native PNG)."""
    import json

    ensure_binary()
    udid = booted_iphone_udid()
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        result_path = td_path / "result.json"
        png_path = td_path / "share.png"
        result_path.write_text(json.dumps(result))

        cmd = [
            "xcrun",
            "simctl",
            "spawn",
            udid,
            str(BIN),
            "--photo",
            str(photo_path.resolve()),
            "--result",
            str(result_path.resolve()),
            "--out",
            str(png_path.resolve()),
            "--logo",
            str(LOGO.resolve()),
        ]
        subprocess.check_call(cmd)

        if out_path.suffix.lower() in {".jpg", ".jpeg"}:
            subprocess.check_call(
                [
                    "sips",
                    "-s",
                    "format",
                    "jpeg",
                    "-s",
                    "formatOptions",
                    "90",
                    str(png_path),
                    "--out",
                    str(out_path),
                ],
                stdout=subprocess.DEVNULL,
            )
        else:
            out_path.write_bytes(png_path.read_bytes())

    return out_path


if __name__ == "__main__":
    import json
    import sys

    photo, result_json, out = map(Path, sys.argv[1:4])
    render_share_card_native(photo, json.loads(result_json.read_text()), out)
    print("wrote", out)
