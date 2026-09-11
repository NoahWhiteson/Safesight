#!/usr/bin/env python3
"""Offline schema + quality checks on committed 20-case benchmark artifacts."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "docs" / "benchmark"


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    report_path = BENCH / "report.json"
    if not report_path.exists():
        fail("docs/benchmark/report.json missing — run scripts/run_benchmark.py")

    report = json.loads(report_path.read_text())
    total = report.get("total")
    passed = report.get("passed")
    cases = report.get("cases") or []

    if total != 20:
        fail(f"expected 20 cases, got total={total}")
    if len(cases) != 20:
        fail(f"expected 20 case rows, got {len(cases)}")
    if passed != 20:
        bad = [c["id"] for c in cases if not c.get("ok")]
        fail(f"not all cases passed: {passed}/{total} — failed: {bad}")

    seen_ids = set()
    for case in cases:
        cid = case.get("id")
        if not cid:
            fail("case missing id")
        if cid in seen_ids:
            fail(f"duplicate case id {cid}")
        seen_ids.add(cid)

        if not case.get("ok"):
            fail(f"case {cid} not ok: {case.get('problems')}")
        if case.get("http") != 200:
            fail(f"case {cid} http={case.get('http')}")

        result_path = BENCH / case["result"]
        share_path = BENCH / case["share"]
        source_path = BENCH / f"source-{cid}.jpg"
        if not result_path.exists():
            fail(f"missing {result_path}")
        if not share_path.exists():
            fail(f"missing {share_path}")
        if share_path.stat().st_size < 8_000:
            fail(f"share card too small: {share_path}")
        if not source_path.exists():
            fail(f"missing source {source_path}")

        data = json.loads(result_path.read_text())
        score = data.get("score")
        if not isinstance(score, int) or not (0 <= score <= 100):
            fail(f"{cid}: invalid score {score}")
        if score != case.get("score"):
            fail(f"{cid}: report score {case.get('score')} != result {score}")

        hazards = data.get("hazards")
        if not isinstance(hazards, list) or not hazards:
            fail(f"{cid}: expected hazards")

        allowed = set(case.get("focusAreas") or [])
        for i, hz in enumerate(hazards):
            box = hz.get("boundingBox") or {}
            for key in ("x", "y", "width", "height"):
                if key not in box:
                    fail(f"{cid}: hazard[{i}] missing box.{key}")
                val = float(box[key])
                if not (0 <= val <= 1.05):
                    fail(f"{cid}: box.{key} out of range: {val}")
            w, h = float(box["width"]), float(box["height"])
            if w > 0.85 or h > 0.85:
                fail(f"{cid}: hazard[{i}] box too large {w}x{h}")
            if w < 0.01 or h < 0.01:
                fail(f"{cid}: hazard[{i}] box too small {w}x{h}")

            conf = hz.get("confidence")
            if not isinstance(conf, (int, float)) or not (0 <= conf <= 100):
                fail(f"{cid}: bad confidence {conf}")
            sev = hz.get("severity")
            if sev not in ("High", "Medium", "Low"):
                fail(f"{cid}: bad severity {sev}")
            title = hz.get("title")
            if not isinstance(title, str) or not title.strip():
                fail(f"{cid}: empty title")
            focus = hz.get("focusArea")
            if allowed and focus and focus not in allowed:
                fail(f"{cid}: focusArea {focus!r} not in {sorted(allowed)}")
            steps = hz.get("fixSteps")
            if not isinstance(steps, list) or len(steps) < 1:
                fail(f"{cid}: missing fixSteps")

        if case.get("problems"):
            fail(f"{cid}: report still has problems {case['problems']}")

    print(
        f"OK — {passed}/{total} cases validated "
        f"({report.get('ranAt')}, model={report.get('model')})"
    )


if __name__ == "__main__":
    main()
