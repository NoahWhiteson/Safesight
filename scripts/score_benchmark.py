#!/usr/bin/env python3
"""
Score Safesight benchmark results against human ground-truth labels.

Matching (greedy best-first):
  1. Alias hit in title/detail (strong)
  2. Else same focusArea AND IoU >= threshold (localization)
  3. Else same focusArea AND pred center inside expanded GT box

Metrics:
  - recall / precision / F1 on required hazards (+ optional GT absorbs FPs)
  - mean IoU on matched pairs that have GT boxes
  - severity exact-match rate on matches
  - House Score within labeled band

Usage:
  python3 scripts/score_benchmark.py
  python3 scripts/score_benchmark.py --fail-under 0.55
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "docs" / "benchmark"
GT_PATH = BENCH / "ground-truth.json"
REPORT_PATH = BENCH / "report.json"
METRICS_PATH = BENCH / "metrics.json"

SEVERITIES = ("High", "Medium", "Low")


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", (s or "").lower()).strip()


def iou(a: dict, b: dict) -> float:
    try:
        ax1, ay1 = float(a["x"]), float(a["y"])
        ax2, ay2 = ax1 + float(a["width"]), ay1 + float(a["height"])
        bx1, by1 = float(b["x"]), float(b["y"])
        bx2, by2 = bx1 + float(b["width"]), by1 + float(b["height"])
    except (KeyError, TypeError, ValueError):
        return 0.0
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def center_in_expanded(pred: dict, gt: dict, pad: float = 0.08) -> bool:
    try:
        px = float(pred["x"]) + float(pred["width"]) / 2
        py = float(pred["y"]) + float(pred["height"]) / 2
        gx, gy = float(gt["x"]) - pad, float(gt["y"]) - pad
        gw, gh = float(gt["width"]) + 2 * pad, float(gt["height"]) + 2 * pad
    except (KeyError, TypeError, ValueError):
        return False
    return gx <= px <= gx + gw and gy <= py <= gy + gh


def alias_hit(pred: dict, gt: dict) -> bool:
    text = norm(f"{pred.get('title', '')} {pred.get('detail', '')}")
    for alias in gt.get("aliases") or []:
        a = norm(alias)
        if a and a in text:
            return True
    return False


def pair_score(pred: dict, gt: dict, iou_thr: float) -> float:
    """Higher is better; 0 = no match.

    GT with a box requires spatial agreement:
      - IoU >= threshold, or
      - alias hit AND prediction center inside a lightly padded GT box
    Focus-only without alias needs IoU >= threshold.
    """
    focus_ok = (pred.get("focusArea") or "") == (gt.get("focusArea") or "")
    aliases = alias_hit(pred, gt)
    has_gt_box = bool(gt.get("box"))
    pred_box = pred.get("boundingBox") or {}
    box_iou = iou(pred_box, gt["box"]) if has_gt_box and pred_box else 0.0

    if has_gt_box:
        if box_iou >= iou_thr:
            if aliases:
                return 3.0 + box_iou
            if focus_ok:
                return 1.5 + box_iou
            return 0.0
        if aliases and center_in_expanded(pred_box, gt["box"]):
            return 2.0 + box_iou
        return 0.0

    if aliases:
        return 2.0
    if focus_ok:
        return 1.0
    return 0.0


def match_case(preds: list[dict], gts: list[dict], iou_thr: float) -> list[tuple[int, int, float]]:
    """Return list of (gt_idx, pred_idx, score) unique matches."""
    candidates: list[tuple[float, int, int]] = []
    for gi, gt in enumerate(gts):
        for pi, pred in enumerate(preds):
            s = pair_score(pred, gt, iou_thr)
            if s > 0:
                candidates.append((s, gi, pi))
    candidates.sort(reverse=True)
    used_g, used_p = set(), set()
    pairs: list[tuple[int, int, float]] = []
    for s, gi, pi in candidates:
        if gi in used_g or pi in used_p:
            continue
        used_g.add(gi)
        used_p.add(pi)
        pairs.append((gi, pi, s))
    return pairs


def score_case(cid: str, case_gt: dict, result: dict, iou_thr: float) -> dict:
    gts = case_gt.get("hazards") or []
    preds = result.get("hazards") or []
    pairs = match_case(preds, gts, iou_thr)

    matched_gt = {gi for gi, _, _ in pairs}
    matched_pred = {pi for _, pi, _ in pairs}

    required = [i for i, g in enumerate(gts) if g.get("required", True)]
    optional = [i for i, g in enumerate(gts) if not g.get("required", True)]

    tp_req = sum(1 for i in required if i in matched_gt)
    fn_req = sum(1 for i in required if i not in matched_gt)
    # Predictions that match optional GT are not false positives
    fp = sum(1 for i in range(len(preds)) if i not in matched_pred)

    recall = tp_req / len(required) if required else 1.0
    precision = (len(matched_pred) / len(preds)) if preds else (1.0 if not required else 0.0)
    if precision + recall > 0:
        f1 = 2 * precision * recall / (precision + recall)
    else:
        f1 = 0.0

    ious = []
    loc_hits = 0
    loc_n = 0
    sev_ok = 0
    sev_n = 0
    matches = []
    for gi, pi, s in pairs:
        gt, pred = gts[gi], preds[pi]
        box_iou = iou(pred.get("boundingBox") or {}, gt.get("box") or {}) if gt.get("box") else None
        if box_iou is not None:
            ious.append(box_iou)
            loc_n += 1
            if box_iou >= 0.3:
                loc_hits += 1
        if gt.get("severity") in SEVERITIES and pred.get("severity") in SEVERITIES:
            sev_n += 1
            if gt["severity"] == pred["severity"]:
                sev_ok += 1
        matches.append(
            {
                "gtId": gt.get("id"),
                "gtFocus": gt.get("focusArea"),
                "predTitle": pred.get("title"),
                "predFocus": pred.get("focusArea"),
                "required": bool(gt.get("required", True)),
                "iou": None if box_iou is None else round(box_iou, 3),
                "localizedAt03": bool(box_iou is not None and box_iou >= 0.3),
                "severityMatch": gt.get("severity") == pred.get("severity"),
            }
        )

    missed = [
        {"id": gts[i].get("id"), "focusArea": gts[i].get("focusArea"), "aliases": gts[i].get("aliases")}
        for i in required
        if i not in matched_gt
    ]
    extras = [
        {
            "title": preds[i].get("title"),
            "focusArea": preds[i].get("focusArea"),
            "severity": preds[i].get("severity"),
        }
        for i in range(len(preds))
        if i not in matched_pred
    ]

    score = result.get("score")
    band = case_gt.get("scoreBand")
    score_in_band = True
    if isinstance(band, list) and len(band) == 2 and isinstance(score, int):
        score_in_band = band[0] <= score <= band[1]

    # Case passes accuracy gate if every required hazard was found and score band ok
    ok = fn_req == 0 and score_in_band

    return {
        "id": cid,
        "label": case_gt.get("label", cid),
        "ok": ok,
        "tpRequired": tp_req,
        "fnRequired": fn_req,
        "fp": fp,
        "requiredCount": len(required),
        "optionalCount": len(optional),
        "predCount": len(preds),
        "recall": round(recall, 4),
        "precision": round(precision, 4),
        "f1": round(f1, 4),
        "meanIoU": round(sum(ious) / len(ious), 4) if ious else None,
        "localizationAt03": round(loc_hits / loc_n, 4) if loc_n else None,
        "severityAgreement": round(sev_ok / sev_n, 4) if sev_n else None,
        "score": score,
        "scoreBand": band,
        "scoreInBand": score_in_band,
        "matches": matches,
        "missedRequired": missed,
        "unmatchedPredictions": extras,
    }


def load_result(cid: str) -> dict:
    path = BENCH / f"result-{cid}.json"
    if not path.exists():
        raise FileNotFoundError(path)
    return json.loads(path.read_text())


def aggregate(cases: list[dict]) -> dict:
    tp = sum(c["tpRequired"] for c in cases)
    fn = sum(c["fnRequired"] for c in cases)
    # precision micro: matched preds / all preds — approximate via per-case
    matched_preds = sum(c["predCount"] - c["fp"] for c in cases)
    all_preds = sum(c["predCount"] for c in cases)
    recall = tp / (tp + fn) if (tp + fn) else 1.0
    precision = matched_preds / all_preds if all_preds else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    ious = [c["meanIoU"] for c in cases if c.get("meanIoU") is not None]
    locs = [c["localizationAt03"] for c in cases if c.get("localizationAt03") is not None]
    sevs = [c["severityAgreement"] for c in cases if c.get("severityAgreement") is not None]
    return {
        "cases": len(cases),
        "casesPassed": sum(1 for c in cases if c["ok"]),
        "microRecall": round(recall, 4),
        "microPrecision": round(precision, 4),
        "microF1": round(f1, 4),
        "macroRecall": round(sum(c["recall"] for c in cases) / len(cases), 4) if cases else 0.0,
        "macroPrecision": round(sum(c["precision"] for c in cases) / len(cases), 4) if cases else 0.0,
        "macroF1": round(sum(c["f1"] for c in cases) / len(cases), 4) if cases else 0.0,
        "meanIoU": round(sum(ious) / len(ious), 4) if ious else None,
        "localizationAt03": round(sum(locs) / len(locs), 4) if locs else None,
        "meanSeverityAgreement": round(sum(sevs) / len(sevs), 4) if sevs else None,
        "scoreBandHits": sum(1 for c in cases if c.get("scoreInBand")),
        "requiredFound": tp,
        "requiredMissed": fn,
        "falsePositives": sum(c["fp"] for c in cases),
    }


def render_readme_section(agg: dict, cases: list[dict]) -> str:
    iou_txt = "n/a" if agg["meanIoU"] is None else f"{agg['meanIoU']*100:.1f}%"
    loc_txt = (
        "n/a"
        if agg.get("localizationAt03") is None
        else f"{agg['localizationAt03']*100:.1f}%"
    )
    sev_txt = (
        "n/a"
        if agg["meanSeverityAgreement"] is None
        else f"{agg['meanSeverityAgreement']*100:.1f}%"
    )
    lines = [
        "## Detection accuracy",
        "",
        "Labeled ground truth in [`ground-truth.json`](./ground-truth.json). "
        "A case **passes** only if every **required** hazard is matched "
        "(alias and/or focus+box) and House Score lands in the labeled band. "
        "Schema-valid junk no longer counts as a pass.",
        "",
        f"- **Required-hazard recall (micro):** {agg['microRecall']*100:.1f}% "
        f"({agg['requiredFound']}/{agg['requiredFound']+agg['requiredMissed']})",
        f"- **Precision (micro):** {agg['microPrecision']*100:.1f}%",
        f"- **F1 (micro):** {agg['microF1']*100:.1f}%",
        f"- **Mean IoU (matched + boxed):** {iou_txt}",
        f"- **Localization @ IoU≥0.3:** {loc_txt}",
        f"- **Severity agreement (matched):** {sev_txt}",
        f"- **Score band hits:** {agg['scoreBandHits']}/{agg['cases']}",
        f"- **Cases with all required hazards found:** {agg['casesPassed']}/{agg['cases']}",
        "",
        "| # | Scene | Recall | Precision | F1 | IoU | Loc@0.3 | Sev | Score | Gate |",
        "|---|-------|--------|-----------|----|-----|---------|-----|-------|------|",
    ]
    for i, c in enumerate(cases, 1):
        mark = "✅" if c["ok"] else "❌"
        iou_s = "—" if c["meanIoU"] is None else f"{c['meanIoU']*100:.0f}%"
        loc_s = "—" if c.get("localizationAt03") is None else f"{c['localizationAt03']*100:.0f}%"
        sev_s = "—" if c["severityAgreement"] is None else f"{c['severityAgreement']*100:.0f}%"
        lines.append(
            f"| {i} | {mark} {c['label']} | {c['recall']*100:.0f}% | {c['precision']*100:.0f}% | "
            f"{c['f1']*100:.0f}% | {iou_s} | {loc_s} | {sev_s} | {c['score']} | "
            f"{'pass' if c['ok'] else 'miss'} |"
        )
    lines.append("")
    misses = [c for c in cases if c["missedRequired"]]
    if misses:
        lines.append("### Missed required hazards")
        lines.append("")
        for c in misses:
            for m in c["missedRequired"]:
                lines.append(
                    f"- **{c['label']}** — `{m['id']}` ({m['focusArea']}; aliases: "
                    f"{', '.join(m.get('aliases') or [])})"
                )
        lines.append("")
    lines.append("")
    return "\n".join(lines)


def patch_readme(section: str) -> None:
    readme = BENCH / "README.md"
    text = readme.read_text()
    start = "## Detection accuracy"
    # Insert after the top result blurb / before "## Safesight in real rooms" or replace existing
    if start in text:
        # replace through next ## that isn't Detection
        pre, rest = text.split(start, 1)
        # find next section after detection block
        idx = rest.find("\n## ")
        if idx >= 0:
            text = pre + section + rest[idx + 1 :]
        else:
            text = pre + section
    else:
        anchor = "## Safesight in real rooms"
        if anchor in text:
            text = text.replace(anchor, section + "\n" + anchor, 1)
        else:
            text = text.rstrip() + "\n\n" + section
    readme.write_text(text)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fail-under", type=float, default=None, help="Exit 1 if micro F1 below this")
    ap.add_argument("--fail-recall-under", type=float, default=None)
    ap.add_argument("--write-readme", action="store_true")
    args = ap.parse_args()

    if not GT_PATH.exists():
        print(f"FAIL: missing {GT_PATH}", file=sys.stderr)
        sys.exit(1)

    gt = json.loads(GT_PATH.read_text())
    iou_thr = float(gt.get("iouThreshold", 0.15))
    case_map = gt.get("cases") or {}
    if len(case_map) != 20:
        print(f"FAIL: ground-truth has {len(case_map)} cases, expected 20", file=sys.stderr)
        sys.exit(1)

    scored = []
    for cid, case_gt in sorted(case_map.items()):
        result = load_result(cid)
        scored.append(score_case(cid, case_gt, result, iou_thr))

    agg = aggregate(scored)
    payload = {
        "version": gt.get("version", 1),
        "iouThreshold": iou_thr,
        "summary": agg,
        "cases": scored,
    }
    METRICS_PATH.write_text(json.dumps(payload, indent=2) + "\n")

    if args.write_readme:
        patch_readme(render_readme_section(agg, scored))

    # Also patch report.json accuracy block if present
    if REPORT_PATH.exists():
        report = json.loads(REPORT_PATH.read_text())
        report["accuracy"] = agg
        REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")

    print(
        f"Accuracy  recall={agg['microRecall']:.3f}  precision={agg['microPrecision']:.3f}  "
        f"F1={agg['microF1']:.3f}  cases={agg['casesPassed']}/{agg['cases']}  "
        f"IoU={agg['meanIoU']}  sev={agg['meanSeverityAgreement']}"
    )
    for c in scored:
        flag = "OK" if c["ok"] else "MISS"
        print(
            f"  [{flag}] {c['id']}: R={c['recall']:.2f} P={c['precision']:.2f} "
            f"F1={c['f1']:.2f} missed={len(c['missedRequired'])} fp={c['fp']}"
        )

    if args.fail_under is not None and agg["microF1"] < args.fail_under:
        print(f"FAIL: micro F1 {agg['microF1']} < {args.fail_under}", file=sys.stderr)
        sys.exit(1)
    if args.fail_recall_under is not None and agg["microRecall"] < args.fail_recall_under:
        print(
            f"FAIL: micro recall {agg['microRecall']} < {args.fail_recall_under}",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
