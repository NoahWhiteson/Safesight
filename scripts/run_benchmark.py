#!/usr/bin/env python3
"""
Live AI benchmark against the hosted Safesight API.
Produces share-card PNGs (ScanShareExporter-style) + a public report.
"""

from __future__ import annotations

import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from render_share_card_native import render_share_card_native as render_share_card

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "docs" / "benchmark"
SECRET_PLIST = ROOT / "Safesight" / "SafesightAPISecrets.plist"
API = "https://safesight.noahwhiteson.com"


def read_secret() -> str:
    out = subprocess.check_output(
        ["/usr/libexec/PlistBuddy", "-c", "Print :API_SECRET", str(SECRET_PLIST)],
        text=True,
    ).strip()
    if not out:
        raise SystemExit("Missing API_SECRET in SafesightAPISecrets.plist")
    return out


def analyze(photo: Path, secret: str, meta: dict) -> tuple[dict, float, int]:
    import tempfile
    import os

    # Use curl for reliable multipart
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
        json.dump(meta, tf)
        meta_path = tf.name
    out_path = tempfile.mktemp(suffix=".json")
    try:
        t0 = time.perf_counter()
        proc = subprocess.run(
            [
                "curl",
                "-sS",
                "-X",
                "POST",
                f"{API}/v1/analyze",
                "-H",
                f"Authorization: Bearer {secret}",
                "-F",
                f"meta=<{meta_path};type=application/json",
                "-F",
                f"image=@{photo};type=image/jpeg",
                "-o",
                out_path,
                "-w",
                "%{http_code}",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        elapsed = time.perf_counter() - t0
        code = int(proc.stdout.strip() or "0")
        with open(out_path) as f:
            data = json.load(f)
        return data, elapsed, code
    finally:
        os.unlink(meta_path)
        if os.path.exists(out_path):
            os.unlink(out_path)


def health() -> dict:
    proc = subprocess.run(
        ["curl", "-sS", f"{API}/health"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(proc.stdout)


CASES = [
    {
        "id": "kitchen",
        "label": "Kitchen",
        "photo": BENCH / "source-kitchen.jpg",
        "focusAreas": [
            "Knives & sharp tools",
            "Slips & trips",
            "Cooking & heat",
            "Poison & chemicals",
            "Falls",
        ],
    },
    {
        "id": "hallway",
        "label": "Hallway",
        "photo": ROOT / "demo-site" / "public" / "rooms" / "hallway.jpg",
        "focusAreas": ["Slips & trips", "Falls", "Clutter & exits", "Lighting"],
    },
    {
        "id": "kitchen-stock",
        "label": "Kitchen (stock)",
        "photo": ROOT / "demo-site" / "public" / "rooms" / "kitchen.jpg",
        "focusAreas": [
            "Knives & sharp tools",
            "Slips & trips",
            "Cooking & heat",
            "Poison & chemicals",
        ],
    },
]


def main():
    BENCH.mkdir(parents=True, exist_ok=True)
    secret = read_secret()
    h = health()
    assert h.get("ok") is True, h
    model = h.get("model", "unknown")

    ran_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    rows = []

    for case in CASES:
        photo = case["photo"]
        if not photo.exists():
            print("skip missing", photo)
            continue
        meta = {
            "scanId": f"benchmark-{case['id']}",
            "focusAreas": case["focusAreas"],
            "dwelling": "House",
            "aggressiveness": 0.55,
            "maxHazards": 4,
        }
        print(f"analyzing {case['id']}…")
        data, elapsed, code = analyze(photo, secret, meta)
        result_path = BENCH / f"result-{case['id']}.json"
        # Copy source into benchmark folder for reproducibility of share card
        source_copy = BENCH / f"source-{case['id']}{photo.suffix}"
        if photo.resolve() != source_copy.resolve():
            source_copy.write_bytes(photo.read_bytes())

        with open(result_path, "w") as f:
            json.dump(data, f, indent=2)

        ok = code == 200 and "score" in data and "error" not in data
        share_path = BENCH / f"share-{case['id']}.jpg"
        if ok:
            render_share_card(source_copy, data, share_path)

        hazards = data.get("hazards") or []
        rows.append(
            {
                "id": case["id"],
                "label": case["label"],
                "ok": ok,
                "http": code,
                "seconds": round(elapsed, 2),
                "score": data.get("score"),
                "summary": data.get("summary"),
                "hazardCount": len(hazards),
                "hazards": [
                    {
                        "title": hz.get("title"),
                        "severity": hz.get("severity"),
                        "confidence": hz.get("confidence"),
                    }
                    for hz in hazards
                ],
                "share": f"share-{case['id']}.jpg" if ok else None,
                "result": f"result-{case['id']}.json",
            }
        )
        print(
            f"  http={code} score={data.get('score')} hazards={len(hazards)} {elapsed:.2f}s"
        )

    passed = sum(1 for r in rows if r["ok"])
    report = {
        "ranAt": ran_at,
        "api": API,
        "model": model,
        "passed": passed,
        "total": len(rows),
        "cases": rows,
    }
    (BENCH / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    # Markdown report
    lines = [
        "# AI benchmark",
        "",
        "Live proof that Safesight’s hosted vision pipeline returns real House Scores,",
        "hazard labels, confidences, and bounding boxes — then exports the **exact same PNG chrome**",
        "as the iOS share sheet via `ScanShareExporter` (simulator CLI → JPEG for GitHub size).",
        "",
        f"- **Ran:** `{ran_at}`",
        f"- **API:** `{API}`",
        f"- **Model:** `{model}` (from `/health`)",
        f"- **Result:** **{passed}/{len(rows)} passed**",
        "",
        "## Cases",
        "",
        "| Scene | HTTP | Latency | House Score | Hazards |",
        "|-------|------|---------|-------------|---------|",
    ]
    for r in rows:
        status = "✅" if r["ok"] else "❌"
        lines.append(
            f"| {status} {r['label']} | {r['http']} | {r['seconds']}s | {r.get('score', '—')} | {r['hazardCount']} |"
        )

    lines += ["", "## Share cards (native `ScanShareExporter`)", ""]
    for r in rows:
        if not r.get("share"):
            continue
        lines += [
            f"### {r['label']} — {r['score']}/100",
            "",
            f"> {r.get('summary') or ''}",
            "",
            "<p align=\"center\">",
            f"  <img src=\"{r['share']}\" alt=\"{r['label']} Safesight share card\" width=\"72%\" />",
            "</p>",
            "",
        ]
        if r["hazards"]:
            lines.append("| Hazard | Severity | Confidence |")
            lines.append("|--------|----------|------------|")
            for hz in r["hazards"]:
                lines.append(
                    f"| {hz['title']} | {hz['severity']} | {hz['confidence']}% |"
                )
            lines.append("")

    lines += [
        "## How to re-run",
        "",
        "```bash",
        "# Requires Safesight/SafesightAPISecrets.plist (gitignored) with API_SECRET",
        "# Share cards use the real ScanShareExporter (iOS Simulator CLI).",
        "python3 scripts/run_benchmark.py",
        "```",
        "",
        "Re-export cards only:",
        "",
        "```bash",
        "python3 scripts/render_share_card_native.py docs/benchmark/source-kitchen.jpg \\",
        "  docs/benchmark/result-kitchen.json docs/benchmark/share-kitchen.jpg",
        "```",
        "",
        "Raw JSON for each case is committed beside the share cards for auditability.",
        "",
        "[← Back to README](../README.md)",
        "",
    ]
    (BENCH / "README.md").write_text("\n".join(lines))
    print(f"report {passed}/{len(rows)} -> {BENCH / 'README.md'}")


if __name__ == "__main__":
    main()
