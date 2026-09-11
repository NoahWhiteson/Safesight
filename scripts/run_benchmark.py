#!/usr/bin/env python3
"""
Live AI benchmark against the hosted Safesight API (20 cases).
Share cards via native ScanShareExporter.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

from render_share_card_native import render_share_card_native as render_share_card

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "docs" / "benchmark"
SOURCES = BENCH / "sources"
SECRET_PLIST = ROOT / "Safesight" / "SafesightAPISecrets.plist"
API = "https://safesight.noahwhiteson.com"

# Match SafetyInterest.rawValue strings the API expects.
FA = {
    "fire": "Fire",
    "water": "Water leaks",
    "electric": "Electric",
    "child": "Child proofing",
    "trip": "Trip hazards",
    "blocked": "Blocked exits",
    "mold": "Mold & stains",
    "chemicals": "Chemical storage",
    "sharp": "Sharp objects",
    "stairs": "Stairs & falls",
    "windows": "Windows & falls",
    "pets": "Pet hazards",
    "paint": "Peeling paint",
    "kitchen": "Kitchen hazards",
    "lighting": "Poor lighting",
    "tip": "Tip-over risks",
}


def case(cid: str, label: str, photo: str, focus: list[str], **opts) -> dict:
    return {
        "id": cid,
        "label": label,
        "photo": SOURCES / photo,
        "focusAreas": focus,
        "aggressiveness": opts.get("aggressiveness", 0.55),
        "maxHazards": opts.get("maxHazards", 4),
        "dwelling": opts.get("dwelling", "House"),
    }


CASES = [
    case(
        "01-kitchen-user",
        "Kitchen (user)",
        "01-kitchen-user.jpg",
        [FA["sharp"], FA["trip"], FA["kitchen"], FA["fire"]],
    ),
    case(
        "02-hallway",
        "Living / hallway",
        "02-hallway.jpg",
        [FA["trip"], FA["blocked"], FA["lighting"], FA["tip"]],
    ),
    case(
        "03-kitchen-stock",
        "Kitchen (stock)",
        "03-kitchen-stock.jpg",
        [FA["kitchen"], FA["sharp"], FA["trip"], FA["fire"]],
    ),
    case(
        "04-kitchen-mid",
        "Kitchen mid crop",
        "04-kitchen-mid.jpg",
        [FA["trip"], FA["electric"], FA["fire"], FA["blocked"]],
    ),
    case(
        "05-kitchen-counter",
        "Kitchen counter crop",
        "05-kitchen-counter.jpg",
        [FA["sharp"], FA["kitchen"], FA["chemicals"]],
        aggressiveness=0.7,
    ),
    case(
        "06-kitchen-floor",
        "Kitchen floor crop",
        "06-kitchen-floor.jpg",
        [FA["trip"], FA["child"], FA["pets"]],
    ),
    case(
        "07-kitchen-oven",
        "Kitchen oven crop",
        "07-kitchen-oven.jpg",
        [FA["fire"], FA["kitchen"], FA["child"]],
        aggressiveness=0.65,
    ),
    case(
        "08-kitchen-island",
        "Kitchen island crop",
        "08-kitchen-island.jpg",
        [FA["sharp"], FA["trip"], FA["kitchen"]],
    ),
    case(
        "09-living-center",
        "Living center crop",
        "09-living-center.jpg",
        [FA["trip"], FA["tip"], FA["electric"]],
    ),
    case(
        "10-living-floor",
        "Living floor crop",
        "10-living-floor.jpg",
        [FA["trip"], FA["child"], FA["pets"]],
        aggressiveness=0.6,
    ),
    case(
        "11-living-left",
        "Living left crop",
        "11-living-left.jpg",
        [FA["windows"], FA["tip"], FA["lighting"]],
    ),
    case(
        "12-living-right",
        "Living right crop",
        "12-living-right.jpg",
        [FA["trip"], FA["blocked"], FA["electric"]],
    ),
    case(
        "13-living-wall",
        "Living wall crop",
        "13-living-wall.jpg",
        [FA["tip"], FA["paint"], FA["electric"]],
        aggressiveness=0.75,
        maxHazards=5,
    ),
    case(
        "14-stock-island",
        "Stock island crop",
        "14-stock-island.jpg",
        [FA["kitchen"], FA["sharp"], FA["fire"]],
    ),
    case(
        "15-stock-cookware",
        "Stock cookware crop",
        "15-stock-cookware.jpg",
        [FA["kitchen"], FA["fire"], FA["child"]],
        aggressiveness=0.7,
    ),
    case(
        "16-stock-floor",
        "Stock floor crop",
        "16-stock-floor.jpg",
        [FA["trip"], FA["child"], FA["pets"]],
    ),
    case(
        "17-stock-wide",
        "Stock wide crop",
        "17-stock-wide.jpg",
        [FA["kitchen"], FA["trip"], FA["blocked"], FA["fire"]],
        maxHazards=5,
    ),
    case(
        "18-kitchen-upper",
        "Kitchen upper crop",
        "18-kitchen-upper.jpg",
        [FA["fire"], FA["electric"], FA["kitchen"]],
        aggressiveness=0.5,
    ),
    case(
        "19-living-close",
        "Living close crop",
        "19-living-close.jpg",
        [FA["trip"], FA["tip"], FA["child"]],
        aggressiveness=0.8,
        maxHazards=5,
    ),
    case(
        "20-stock-corner",
        "Stock corner crop",
        "20-stock-corner.jpg",
        [FA["kitchen"], FA["sharp"], FA["chemicals"]],
        aggressiveness=0.65,
    ),
]

assert len(CASES) == 20, len(CASES)


def read_secret() -> str:
    out = subprocess.check_output(
        ["/usr/libexec/PlistBuddy", "-c", "Print :API_SECRET", str(SECRET_PLIST)],
        text=True,
    ).strip()
    if not out:
        raise SystemExit("Missing API_SECRET in SafesightAPISecrets.plist")
    return out


def analyze(photo: Path, secret: str, meta: dict) -> tuple[dict, float, int, str]:
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
        raw = Path(out_path).read_text() if Path(out_path).exists() else ""
        try:
            data = json.loads(raw) if raw else {"error": "empty body"}
        except json.JSONDecodeError:
            data = {"error": "non-json", "body": raw[:400]}
        return data, elapsed, code, raw
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


def check_result(data: dict, allowed_focus: list[str]) -> list[str]:
    """Return list of validation problems (empty = ok)."""
    problems: list[str] = []
    if "error" in data and "score" not in data:
        problems.append(f"api error: {data.get('error')}")
        return problems

    score = data.get("score")
    if not isinstance(score, int) or not (0 <= score <= 100):
        problems.append(f"bad score: {score!r}")

    summary = data.get("summary")
    if not isinstance(summary, str) or not summary.strip():
        problems.append("missing summary")
    elif len(summary) > 160:
        problems.append(f"summary too long ({len(summary)})")

    hazards = data.get("hazards")
    if not isinstance(hazards, list):
        problems.append("hazards not a list")
        return problems
    if len(hazards) < 1:
        problems.append("no hazards returned")

    for i, hz in enumerate(hazards):
        if not isinstance(hz, dict):
            problems.append(f"hazard[{i}] not object")
            continue
        title = hz.get("title")
        if not isinstance(title, str) or not title.strip():
            problems.append(f"hazard[{i}] missing title")
        sev = hz.get("severity")
        if sev not in ("High", "Medium", "Low"):
            problems.append(f"hazard[{i}] bad severity {sev!r}")
        conf = hz.get("confidence")
        if not isinstance(conf, (int, float)) or not (0 <= float(conf) <= 100):
            problems.append(f"hazard[{i}] bad confidence {conf!r}")
        focus = hz.get("focusArea")
        if focus and allowed_focus and focus not in allowed_focus:
            problems.append(f"hazard[{i}] focusArea {focus!r} not in request")
        box = hz.get("boundingBox") or {}
        for key in ("x", "y", "width", "height"):
            if key not in box:
                problems.append(f"hazard[{i}] missing box.{key}")
                continue
            try:
                val = float(box[key])
            except (TypeError, ValueError):
                problems.append(f"hazard[{i}] box.{key} not numeric")
                continue
            if not (0 <= val <= 1.05):
                problems.append(f"hazard[{i}] box.{key}={val} out of 0…1")
        try:
            w = float(box.get("width", 0))
            h = float(box.get("height", 0))
            if w > 0.85 or h > 0.85:
                problems.append(f"hazard[{i}] box too large ({w:.2f}x{h:.2f})")
            if w < 0.01 or h < 0.01:
                problems.append(f"hazard[{i}] box too small ({w:.2f}x{h:.2f})")
        except (TypeError, ValueError):
            pass
        steps = hz.get("fixSteps")
        if not isinstance(steps, list) or len(steps) < 1:
            problems.append(f"hazard[{i}] missing fixSteps")

    return problems


def shrink_share_for_docs(path: Path) -> None:
    """Keep GitHub-friendly size: max long edge 1000, jpeg q78."""
    if not path.exists():
        return
    subprocess.run(
        [
            "sips",
            "-Z",
            "1000",
            "-s",
            "format",
            "jpeg",
            "-s",
            "formatOptions",
            "78",
            str(path),
            "--out",
            str(path),
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    assert len(CASES) == 20
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
            rows.append(
                {
                    "id": case["id"],
                    "label": case["label"],
                    "ok": False,
                    "http": 0,
                    "seconds": 0,
                    "score": None,
                    "summary": None,
                    "hazardCount": 0,
                    "hazards": [],
                    "problems": ["missing source photo"],
                    "share": None,
                    "result": f"result-{case['id']}.json",
                }
            )
            continue

        meta = {
            "scanId": f"benchmark-{case['id']}",
            "focusAreas": case["focusAreas"],
            "dwelling": case["dwelling"],
            "aggressiveness": case["aggressiveness"],
            "maxHazards": case["maxHazards"],
        }
        print(f"analyzing {case['id']}…")
        data, elapsed, code, _raw = analyze(photo, secret, meta)
        result_path = BENCH / f"result-{case['id']}.json"
        source_copy = BENCH / f"source-{case['id']}.jpg"
        if photo.resolve() != source_copy.resolve():
            source_copy.write_bytes(photo.read_bytes())

        with open(result_path, "w") as f:
            json.dump(data, f, indent=2)

        problems = []
        if code != 200:
            problems.append(f"http {code}")
        problems.extend(check_result(data, case["focusAreas"]))

        ok = code == 200 and not problems
        share_path = BENCH / f"share-{case['id']}.jpg"
        if ok:
            try:
                render_share_card(source_copy, data, share_path)
                shrink_share_for_docs(share_path)
            except Exception as e:
                problems.append(f"share export failed: {e}")
                ok = False

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
                "hazardCount": len(hazards) if isinstance(hazards, list) else 0,
                "hazards": [
                    {
                        "title": hz.get("title"),
                        "severity": hz.get("severity"),
                        "confidence": hz.get("confidence"),
                        "focusArea": hz.get("focusArea"),
                    }
                    for hz in (hazards if isinstance(hazards, list) else [])
                    if isinstance(hz, dict)
                ],
                "problems": problems,
                "share": f"share-{case['id']}.jpg" if ok and share_path.exists() else None,
                "result": f"result-{case['id']}.json",
                "focusAreas": case["focusAreas"],
                "aggressiveness": case["aggressiveness"],
            }
        )
        status = "OK" if ok else "FAIL"
        print(
            f"  {status} http={code} score={data.get('score')} "
            f"hazards={len(hazards) if isinstance(hazards, list) else 0} "
            f"{elapsed:.2f}s {problems or ''}"
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

    lines = [
        "# AI benchmark",
        "",
        "Live proof that Safesight’s hosted vision pipeline returns real House Scores,",
        "hazard labels, confidences, and bounding boxes — then exports via the **exact**",
        "iOS `ScanShareExporter` (simulator CLI).",
        "",
        f"- **Ran:** `{ran_at}`",
        f"- **API:** `{API}`",
        f"- **Model:** `{model}` (from `/health`)",
        f"- **Result:** **{passed}/{len(rows)} passed**",
        "",
        "## Cases",
        "",
        "| # | Scene | HTTP | Latency | Score | Hazards | Check |",
        "|---|-------|------|---------|-------|---------|-------|",
    ]
    for i, r in enumerate(rows, 1):
        status = "✅" if r["ok"] else "❌"
        check = "ok" if r["ok"] else "; ".join(r.get("problems") or ["fail"])
        lines.append(
            f"| {i} | {status} {r['label']} | {r['http']} | {r['seconds']}s | "
            f"{r.get('score', '—')} | {r['hazardCount']} | {check} |"
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
            f"  <img src=\"{r['share']}\" alt=\"{r['label']} Safesight share card\" width=\"52%\" />",
            "</p>",
            "",
        ]
        if r["hazards"]:
            lines.append("| Hazard | Severity | Confidence | Focus |")
            lines.append("|--------|----------|------------|-------|")
            for hz in r["hazards"]:
                lines.append(
                    f"| {hz['title']} | {hz['severity']} | {hz['confidence']}% | {hz.get('focusArea') or '—'} |"
                )
            lines.append("")

    lines += [
        "## How to re-run",
        "",
        "```bash",
        "# Requires Safesight/SafesightAPISecrets.plist (gitignored) with API_SECRET",
        "python3 scripts/run_benchmark.py",
        "python3 scripts/validate_benchmark.py",
        "```",
        "",
        "Sources live in `docs/benchmark/sources/` (full frames + crops of real room photos).",
        "",
        "[← Back to README](../README.md)",
        "",
    ]
    (BENCH / "README.md").write_text("\n".join(lines))
    print(f"\nreport {passed}/{len(rows)} -> {BENCH / 'README.md'}")
    if passed != len(rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
