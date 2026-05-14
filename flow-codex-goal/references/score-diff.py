#!/usr/bin/env python3
"""
score-diff.py — 对比 milestone score vs baseline，按 Goal-Attainment Mode 判定是否退化

用法:
  python3 score-diff.py \
    --baseline .agent/tasks/<id>/BASELINE.md \
    --current  .agent/tasks/<id>/scores/milestone-N.json \
    --mode     regression-prevention \
    [--threshold 4.0] \
    [--no-improvement-history .agent/tasks/<id>/scores/aggregate-trend.json] \
    [--n 3]

退出码:
  0 = OK 继续
  1 = 退化 / 不达标 / 应停止
  2 = 数据缺失
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_baseline_md(p: Path) -> dict:
    if not p.exists():
        return {}
    text = p.read_text()
    scores = {}
    aggregate = None
    for line in text.splitlines():
        m = re.match(r"-\s*(Correctness|Maintainability|UX|Risk):\s*(\d+(?:\.\d+)?)/5", line)
        if m:
            scores[m.group(1).lower()] = float(m.group(2))
        m = re.match(r"-\s*Aggregate:\s*(\d+(?:\.\d+)?)", line)
        if m:
            aggregate = float(m.group(1))
    return {"scores": scores, "aggregate": aggregate}


def load_milestone_json(p: Path) -> dict:
    if not p.exists():
        return {}
    return json.loads(p.read_text())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", required=True, type=Path)
    ap.add_argument("--current", required=True, type=Path)
    ap.add_argument("--mode", required=True,
                    choices=["threshold", "no-improvement-N",
                             "regression-prevention", "hybrid"])
    ap.add_argument("--threshold", type=float, default=4.0)
    ap.add_argument("--n", type=int, default=3)
    ap.add_argument("--no-improvement-history", type=Path)
    args = ap.parse_args()

    baseline = parse_baseline_md(args.baseline)
    current = load_milestone_json(args.current)

    if not baseline or not current:
        print(json.dumps({"verdict": "data-missing",
                          "baseline_loaded": bool(baseline),
                          "current_loaded": bool(current)}))
        return 2

    b_scores = baseline.get("scores", {})
    c_scores = current.get("scores", {})
    c_agg = current.get("aggregate")

    issues = []
    verdict = "ok"

    if args.mode in ("regression-prevention", "hybrid"):
        for dim in ("correctness", "maintainability", "ux", "risk"):
            b = b_scores.get(dim)
            c = c_scores.get(dim)
            if b is None or c is None:
                continue
            if c < b:
                issues.append(f"{dim} regressed: {b} -> {c}")
                verdict = "stop-regression"

    if args.mode in ("threshold", "hybrid") and c_agg is not None:
        if c_agg < args.threshold:
            issues.append(f"aggregate {c_agg} < threshold {args.threshold}")
            if verdict == "ok":
                verdict = "stop-below-threshold"

    if args.mode in ("no-improvement-N", "hybrid") and args.no_improvement_history:
        history = []
        if args.no_improvement_history.exists():
            history = json.loads(args.no_improvement_history.read_text())
        history.append({"milestone": current.get("milestone"), "aggregate": c_agg})
        args.no_improvement_history.parent.mkdir(parents=True, exist_ok=True)
        args.no_improvement_history.write_text(json.dumps(history, indent=2))

        if len(history) >= args.n:
            recent = [h["aggregate"] for h in history[-args.n:] if h["aggregate"] is not None]
            if len(recent) >= args.n and max(recent) <= recent[0]:
                issues.append(f"no improvement in last {args.n} milestones: {recent}")
                if verdict == "ok":
                    verdict = "stop-no-improvement"

    out = {
        "verdict": verdict,
        "mode": args.mode,
        "baseline_aggregate": baseline.get("aggregate"),
        "current_aggregate": c_agg,
        "delta": (c_agg - baseline.get("aggregate"))
                 if c_agg is not None and baseline.get("aggregate") is not None
                 else None,
        "issues": issues,
    }
    print(json.dumps(out, indent=2))
    return 0 if verdict == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
