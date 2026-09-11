#!/usr/bin/env python3
"""
Live AI benchmark against the hosted Safesight API (20 distinct room photos).
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


# 20 distinct photos (unique files — not crops of the same frame).
CASES = [
    case("01-kitchen-user", "Kitchen (user)", "01-kitchen-user.jpg",
         [FA["sharp"], FA["trip"], FA["kitchen"], FA["fire"]]),
    case("02-living-hallway", "Living / hallway", "02-living-hallway.jpg",
         [FA["trip"], FA["blocked"], FA["lighting"], FA["tip"]]),
    case("03-kitchen-stock", "Kitchen (stock)", "03-kitchen-stock.jpg",
         [FA["kitchen"], FA["sharp"], FA["trip"], FA["fire"]]),
    case("04-bathroom", "Bathroom", "04-bathroom.jpg",
         [FA["trip"], FA["water"], FA["child"], FA["mold"]], aggressiveness=0.65),
    case("05-bedroom", "Bedroom", "05-bedroom.jpg",
         [FA["tip"], FA["electric"], FA["fire"], FA["windows"]]),
    case("06-living-sofa", "Living (sofa)", "06-living-sofa.jpg",
         [FA["trip"], FA["tip"], FA["electric"], FA["pets"]]),
    case("07-kitchen-white", "Kitchen (white)", "07-kitchen-white.jpg",
         [FA["kitchen"], FA["sharp"], FA["fire"], FA["trip"]]),
    case("08-bedroom-boho", "Bedroom (boho)", "08-bedroom-boho.jpg",
         [FA["electric"], FA["tip"], FA["fire"], FA["windows"]], aggressiveness=0.6),
    case("09-laundry", "Laundry room", "09-laundry.jpg",
         [FA["trip"], FA["water"], FA["electric"], FA["fire"], FA["chemicals"]], aggressiveness=0.7),
    case("10-living-windows", "Living (windows)", "10-living-windows.jpg",
         [FA["windows"], FA["trip"], FA["tip"], FA["lighting"]]),
    case("11-dining", "Dining room", "11-dining.jpg",
         [FA["fire"], FA["sharp"], FA["tip"], FA["child"]], aggressiveness=0.6),
    case("12-living-modern", "Living (modern)", "12-living-modern.jpg",
         [FA["trip"], FA["tip"], FA["electric"], FA["pets"]]),
    case("13-living-stairs", "Living + stairs", "13-living-stairs.jpg",
         [FA["stairs"], FA["trip"], FA["kitchen"], FA["child"]], aggressiveness=0.65, maxHazards=5),
    case("14-kitchen-cooking", "Kitchen (cooking)", "14-kitchen-cooking.jpg",
         [FA["fire"], FA["kitchen"], FA["sharp"], FA["child"]], aggressiveness=0.7),
    case("15-home-office", "Home office", "15-home-office.jpg",
         [FA["electric"], FA["trip"], FA["fire"], FA["tip"]]),
    case("16-bathroom-modern", "Bathroom (modern)", "16-bathroom-modern.jpg",
         [FA["trip"], FA["water"], FA["child"], FA["mold"]]),
    case("17-closet", "Closet / wardrobe", "17-closet.jpg",
         [FA["tip"], FA["fire"], FA["child"], FA["electric"]], aggressiveness=0.75),
    case("18-kitchen-island", "Kitchen (island)", "18-kitchen-island.jpg",
         [FA["kitchen"], FA["fire"], FA["sharp"], FA["trip"]]),
    case("19-patio-door", "Open plan + patio", "19-patio-door.jpg",
         [FA["windows"], FA["trip"], FA["fire"], FA["blocked"], FA["child"]], maxHazards=5),
    case("20-garage", "Garage", "20-garage.jpg",
         [FA["fire"], FA["chemicals"], FA["trip"], FA["electric"]], aggressiveness=0.7),
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


def analyze(photo: Path, secret: str, meta: dict) -> tuple[dict, float, int]:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
        json.dump(meta, tf)
        meta_path = tf.name
    out_path = tempfile.mktemp(suffix=".json")
    try:
        t0 = time.perf_counter()
        proc = subprocess.run(
            [
                "curl", "-sS", "-X", "POST", f"{API}/v1/analyze",
                "-H", f"Authorization: Bearer {secret}",
                "-F", f"meta=<{meta_path};type=application/json",
                "-F", f"image=@{photo};type=image/jpeg",
                "-o", out_path, "-w", "%{http_code}",
            ],
            capture_output=True, text=True, check=False,
        )
        elapsed = time.perf_counter() - t0
        code = int(proc.stdout.strip() or "0")
        raw = Path(out_path).read_text() if Path(out_path).exists() else ""
        try:
            data = json.loads(raw) if raw else {"error": "empty body"}
        except json.JSONDecodeError:
            data = {"error": "non-json", "body": raw[:400]}
        return data, elapsed, code
    finally:
        os.unlink(meta_path)
        if os.path.exists(out_path):
            os.unlink(out_path)


def health() -> dict:
    proc = subprocess.run(
        ["curl", "-sS", f"{API}/health"], capture_output=True, text=True, check=True
    )
    return json.loads(proc.stdout)


def check_result(data: dict, allowed_focus: list[str]) -> list[str]:
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
        if not isinstance(hz.get("title"), str) or not hz["title"].strip():
            problems.append(f"hazard[{i}] missing title")
        if hz.get("severity") not in ("High", "Medium", "Low"):
            problems.append(f"hazard[{i}] bad severity {hz.get('severity')!r}")
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
            w, h = float(box.get("width", 0)), float(box.get("height", 0))
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
    if not path.exists():
        return
    subprocess.run(
        ["sips", "-Z", "1000", "-s", "format", "jpeg", "-s", "formatOptions", "78",
         str(path), "--out", str(path)],
        check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def main():
    assert len(CASES) == 20
    # Guard: every source must exist and be a unique file hash
    hashes = []
    for c in CASES:
        if not c["photo"].exists():
            raise SystemExit(f"missing source {c['photo']}")
        h = subprocess.check_output(["md5", "-q", str(c["photo"])], text=True).strip()
        hashes.append(h)
    if len(set(hashes)) != 20:
        raise SystemExit("source photos are not all unique — refusing to run")

    BENCH.mkdir(parents=True, exist_ok=True)
    secret = read_secret()
    h = health()
    assert h.get("ok") is True, h
    model = h.get("model", "unknown")
    ran_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    rows = []

    for case in CASES:
        photo = case["photo"]
        meta = {
            "scanId": f"benchmark-{case['id']}",
            "focusAreas": case["focusAreas"],
            "dwelling": case["dwelling"],
            "aggressiveness": case["aggressiveness"],
            "maxHazards": case["maxHazards"],
        }
        print(f"analyzing {case['id']}…")
        data, elapsed, code = analyze(photo, secret, meta)
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
        rows.append({
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
        })
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
        "distinctSources": 20,
        "cases": rows,
    }
    (BENCH / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    lines = [
        "# AI benchmark",
        "",
        "Live proof on **20 distinct room photos** (unique files — not crops of one scene).",
        "Share cards are the exact iOS `ScanShareExporter` output.",
        "",
        f"- **Ran:** `{ran_at}`",
        f"- **API:** `{API}`",
        f"- **Model:** `{model}`",
        f"- **Result:** **{passed}/{len(rows)} passed**",
        "",
        "## Safesight in real rooms",
        "",
        "Real scans from the app — boxes on the photo, confidence on each label, House Score on the share card.",
        "",
        "<p align=\"center\">",
        "  <img src=\"../assets/share-examples/desk.jpg\" alt=\"Desk scan — House Score 88\" width=\"46%\" />",
        "  &nbsp;",
        "  <img src=\"../assets/share-examples/bathroom.jpg\" alt=\"Bathroom scan — House Score 82\" width=\"46%\" />",
        "</p>",
        "<p align=\"center\">",
        "  <sub>Desk · 88/100 &nbsp;·&nbsp; Bathroom · 82/100</sub>",
        "</p>",
        "",
        "<p align=\"center\">",
        "  <img src=\"../assets/share-examples/hallway.jpg\" alt=\"Hallway scan — House Score 68\" width=\"46%\" />",
        "  &nbsp;",
        "  <img src=\"../assets/share-examples/kitchen.jpg\" alt=\"Kitchen scan — House Score 78\" width=\"46%\" />",
        "</p>",
        "<p align=\"center\">",
        "  <sub>Hallway · 68/100 &nbsp;·&nbsp; Kitchen · 78/100</sub>",
        "</p>",
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
        "[← Back to README](../README.md)",
        "",
    ]
    (BENCH / "README.md").write_text("\n".join(lines))
    print(f"\nreport {passed}/{len(rows)} -> {BENCH / 'README.md'}")
    if passed != len(rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
