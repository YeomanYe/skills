#!/usr/bin/env python3
"""
kdroi.py — Batch KDRoi scorer for SEO niche keywords.

Reads a Semrush/Ahrefs/Google-Ads-like CSV export and produces a KDRoi-sorted
Markdown table of keyword candidates.

KDRoi = Volume * CPC / KD

Default new-user filters (the "niche-finder" starter config):
  - KD in [0, 29]
  - Volume in [200, 10000]
  - CPC >= 0.1
  - Keyword does not contain "near me"

Usage:
  python3 kdroi.py <csv_path>
  python3 kdroi.py <csv_path> --top 30
  python3 kdroi.py <csv_path> --kd-max 50 --vol-min 100 --vol-max 20000 --cpc-min 0.05
  python3 kdroi.py <csv_path> --no-filter   # keep all rows, just rank

Column auto-detection: the script tries to find Keyword, Volume, CPC, KD
columns case-insensitively. Common synonyms are recognized
(e.g. "Search Volume", "Keyword Difficulty").

Exit codes:
  0 — success
  1 — file not found or unreadable
  2 — required columns not detected
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


COLUMN_ALIASES = {
    "keyword": ["keyword", "keywords", "term", "query", "phrase"],
    "volume": ["volume", "search volume", "avg. monthly searches", "searches", "vol"],
    "cpc": ["cpc", "cpc (usd)", "cost per click", "avg cpc"],
    "kd": ["kd", "keyword difficulty", "difficulty", "kd %"],
}


def normalize(name: str) -> str:
    return name.strip().lower().replace("_", " ").replace("-", " ")


def detect_column(fieldnames: list[str], target: str) -> str | None:
    normalized_map = {normalize(f): f for f in fieldnames}
    for alias in COLUMN_ALIASES[target]:
        if alias in normalized_map:
            return normalized_map[alias]
    for alias in COLUMN_ALIASES[target]:
        for norm, original in normalized_map.items():
            if alias in norm:
                return original
    return None


def parse_float(value: str) -> float | None:
    if value is None:
        return None
    cleaned = value.strip().replace(",", "").replace("$", "").replace("%", "")
    if cleaned == "" or cleaned.lower() in {"n/a", "null", "-"}:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute KDRoi scores and rank SEO keyword candidates.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Filters are applied before ranking. Use --no-filter to disable."
        ),
    )
    parser.add_argument("csv_path", type=Path, help="Path to the CSV export.")
    parser.add_argument("--top", type=int, default=20, help="Top N rows to show (default 20).")
    parser.add_argument("--kd-max", type=float, default=29.0, help="Max KD (default 29).")
    parser.add_argument("--vol-min", type=float, default=200.0, help="Min Volume (default 200).")
    parser.add_argument("--vol-max", type=float, default=10000.0, help="Max Volume (default 10000).")
    parser.add_argument("--cpc-min", type=float, default=0.1, help="Min CPC (default 0.1).")
    parser.add_argument(
        "--exclude",
        action="append",
        default=["near me"],
        help="Exclude keywords containing this substring (case-insensitive). "
        "Can be used multiple times. Default: 'near me'.",
    )
    parser.add_argument(
        "--no-filter",
        action="store_true",
        help="Skip all filters; just rank by KDRoi.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.csv_path.exists():
        print(f"ERROR: file not found: {args.csv_path}", file=sys.stderr)
        return 1

    try:
        with args.csv_path.open(encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            fieldnames = reader.fieldnames or []
            kw_col = detect_column(fieldnames, "keyword")
            vol_col = detect_column(fieldnames, "volume")
            cpc_col = detect_column(fieldnames, "cpc")
            kd_col = detect_column(fieldnames, "kd")
            missing = [
                label
                for label, col in (
                    ("Keyword", kw_col),
                    ("Volume", vol_col),
                    ("CPC", cpc_col),
                    ("KD", kd_col),
                )
                if col is None
            ]
            if missing:
                print(
                    f"ERROR: cannot detect required columns: {', '.join(missing)}",
                    file=sys.stderr,
                )
                print(f"Available columns: {fieldnames}", file=sys.stderr)
                return 2
            rows = list(reader)
    except OSError as e:
        print(f"ERROR: cannot read file: {e}", file=sys.stderr)
        return 1

    excludes = [s.lower() for s in (args.exclude or []) if s]

    scored: list[dict] = []
    skipped_parse = 0
    skipped_filter = 0

    for row in rows:
        keyword = (row.get(kw_col) or "").strip()
        volume = parse_float(row.get(vol_col))
        cpc = parse_float(row.get(cpc_col))
        kd = parse_float(row.get(kd_col))

        if not keyword or volume is None or cpc is None or kd is None:
            skipped_parse += 1
            continue
        if kd <= 0:
            kd = 1.0

        if not args.no_filter:
            if kd > args.kd_max:
                skipped_filter += 1
                continue
            if volume < args.vol_min or volume > args.vol_max:
                skipped_filter += 1
                continue
            if cpc < args.cpc_min:
                skipped_filter += 1
                continue
            kw_lower = keyword.lower()
            if any(x in kw_lower for x in excludes):
                skipped_filter += 1
                continue

        kdroi = volume * cpc / kd
        scored.append(
            {
                "keyword": keyword,
                "volume": volume,
                "cpc": cpc,
                "kd": kd,
                "kdroi": kdroi,
            }
        )

    scored.sort(key=lambda x: x["kdroi"], reverse=True)

    print(f"# KDRoi 排序结果\n")
    print(f"- 源文件：`{args.csv_path}`")
    print(f"- 原始行数：{len(rows)}")
    print(f"- 跳过（数据缺失）：{skipped_parse}")
    if not args.no_filter:
        print(
            f"- 跳过（过滤）：{skipped_filter}  | 过滤条件：KD≤{args.kd_max}, "
            f"{args.vol_min:.0f}≤Volume≤{args.vol_max:.0f}, CPC≥{args.cpc_min}, "
            f"exclude={args.exclude}"
        )
    else:
        print("- 过滤：**关闭**（--no-filter）")
    print(f"- 通过：{len(scored)}，显示 Top {min(args.top, len(scored))}\n")

    if not scored:
        print("_（没有通过过滤的关键词。可尝试 `--no-filter` 或放宽阈值。）_")
        return 0

    print("| 排名 | 关键词 | Volume | CPC | KD | KDRoi |")
    print("|---|---|---:|---:|---:|---:|")
    for i, r in enumerate(scored[: args.top], start=1):
        print(
            f"| {i} | {r['keyword']} | {r['volume']:.0f} | "
            f"${r['cpc']:.2f} | {r['kd']:.0f} | {r['kdroi']:.0f} |"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
