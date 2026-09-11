#!/usr/bin/env python3
"""Offline schema checks on committed benchmark artifacts (no API secret needed)."""

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
    if report.get("passed", 0) < 1:
        fail("benchmark report has zero passing cases")
    if report.get("passed") != report.get("total"):
        fail(f"not all cases passed: {report.get('passed')}/{report.get('total')}")

    for case in report.get("cases") or []:
        if not case.get("ok"):
            fail(f"case {case.get('id')} not ok")
        result_path = BENCH / case["result"]
        share_path = BENCH / case["share"]
        if not result_path.exists():
            fail(f"missing {result_path}")
        if not share_path.exists():
            fail(f"missing {share_path}")
        if share_path.stat().st_size < 10_000:
            fail(f"share card too small: {share_path}")

        data = json.loads(result_path.read_text())
        score = data.get("score")
        if not isinstance(score, int) or not (0 <= score <= 100):
            fail(f"{case['id']}: invalid score {score}")
        hazards = data.get("hazards")
        if not isinstance(hazards, list) or not hazards:
            fail(f"{case['id']}: expected hazards")
        for hz in hazards:
            box = hz.get("boundingBox") or {}
            for key in ("x", "y", "width", "height"):
                if key not in box:
                    fail(f"{case['id']}: hazard missing box.{key}")
                val = float(box[key])
                if not (0 <= val <= 1.05):
                    fail(f"{case['id']}: box.{key} out of range: {val}")
            conf = hz.get("confidence")
            if not isinstance(conf, (int, float)) or not (0 <= conf <= 100):
                fail(f"{case['id']}: bad confidence {conf}")

    print(f"OK — {report['passed']}/{report['total']} cases validated ({report.get('ranAt')})")


if __name__ == "__main__":
    main()
