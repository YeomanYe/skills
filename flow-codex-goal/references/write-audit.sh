#!/usr/bin/env bash
# write-audit.sh — 写 review-audit/round-N.jsonl 一行
#
# 用法:
#   ./write-audit.sh <task-id> <round-name> <review-type>
#     review-type ∈ {baseline, mini-review, final-review}
#
# 读取:
#   .agent/tasks/<id>/scores/<round>.json     (mini-review 用)
#   .agent/tasks/<id>/reviews/round-N/REVIEW.md  (final-review 用)
#   .agent/tasks/<id>/BASELINE.md             (baseline 用)
#
# 输出:
#   写入 .agent/tasks/<id>/review-audit/round-N.jsonl
#   同时更新 review-audit/INDEX.md（人类可读摘要）

set -u

TASK_ID="${1:?task-id required}"
ROUND="${2:?round name required}"
TYPE="${3:?review-type required}"

TASK_DIR=".agent/tasks/$TASK_ID"
AUDIT_DIR="$TASK_DIR/review-audit"
mkdir -p "$AUDIT_DIR"

JSONL="$AUDIT_DIR/round-${ROUND}.jsonl"
INDEX="$AUDIT_DIR/INDEX.md"

ts=$(date -u +%FT%TZ)
goal_md_sha=""
[[ -f "$TASK_DIR/GOAL.md" ]] && goal_md_sha=$(shasum -a 256 "$TASK_DIR/GOAL.md" 2>/dev/null | awk '{print $1}')

# 提取 reviewer pid 和 thread id
reviewer_pid=""
reviewer_thread=""
case "$TYPE" in
  baseline)
    src="$TASK_DIR/BASELINE.md"
    [[ -f "$src" ]] && reviewer_pid=$(grep -oE 'reviewer_pid:\s*[0-9]+' "$src" | awk '{print $2}' || echo "")
    [[ -f "$src" ]] && reviewer_thread=$(grep -oE 'reviewer_thread_id:\s*\S+' "$src" | awk '{print $2}' || echo "")
    verdict="baseline-recorded"
    aggregate=$(grep -oE 'Aggregate:\s*[0-9.]+' "$src" | head -1 | awk '{print $2}' || echo "")
    ;;
  mini-review)
    src="$TASK_DIR/scores/${ROUND}.json"
    [[ -f "$src" ]] || { echo "ERR: $src not found" >&2; exit 1; }
    reviewer_pid=$(jq -r '.reviewer_pid // ""' "$src" 2>/dev/null || echo "")
    reviewer_thread=$(jq -r '.reviewer_thread_id // ""' "$src" 2>/dev/null || echo "")
    verdict=$(jq -r '.verdict // "n/a"' "$src" 2>/dev/null || echo "n/a")
    aggregate=$(jq -r '.aggregate // 0' "$src" 2>/dev/null || echo "0")
    ;;
  final-review)
    # v4: 同时处理 codex-reviewer + 所有 extra reviewers
    # 每个 reviewer 各写一行 JSONL，reviewer_name 字段区分
    src="$TASK_DIR/reviews/round-${ROUND}/REVIEW.md"
    [[ -f "$src" ]] || { echo "ERR: $src not found" >&2; exit 1; }
    # 从 ## Reviewer Metadata 段解析
    reviewer_pid=$(awk '/^## Reviewer Metadata/{flag=1;next} /^## /{flag=0} flag && /^- PID:/{print $3; exit}' "$src")
    reviewer_thread=$(awk '/^## Reviewer Metadata/{flag=1;next} /^## /{flag=0} flag && /^- Thread:/{print $3; exit}' "$src")
    reviewer_launch_cmd=$(awk '/^## Reviewer Metadata/{flag=1;next} /^## /{flag=0} flag && /^- Launch cmd:/{sub(/^- Launch cmd: /,""); print; exit}' "$src")
    reviewer_worktree_sha=$(awk '/^## Reviewer Metadata/{flag=1;next} /^## /{flag=0} flag && /^- Worktree SHA:/{print $4; exit}' "$src")
    # verdict: case-insensitive
    verdict=$(awk '/^## Verdict/{flag=1;next} /^## /{flag=0} flag && NF>0 {print tolower($1); exit}' "$src")
    aggregate=$(grep -oE 'Aggregate:\s*[0-9.]+' "$src" | head -1 | awk '{print $2}')
    ;;
  *)
    echo "ERR: unknown type $TYPE" >&2
    exit 1
    ;;
esac

# 提取扩展字段（仅 final-review 时尝试）
must_fix_json="[]"
should_fix_json="[]"
new_rules_json="[]"
delta_json="null"
runtime_json="null"

if [[ "$TYPE" == "final-review" ]] && [[ -f "$src" ]]; then
  # Must Fix 段：粗略提取 "- File / location:" 行
  must_fix_json=$(awk '/^## Must Fix/{flag=1;next} /^## /{flag=0} flag && /^- File/' "$src" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
  should_fix_json=$(awk '/^## Should Fix/{flag=1;next} /^## /{flag=0} flag && /^- File/' "$src" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
fi

# 写 JSONL 一行
jq -n \
  --arg round "$ROUND" \
  --arg type "$TYPE" \
  --arg ts "$ts" \
  --arg reviewer_pid "$reviewer_pid" \
  --arg reviewer_thread "$reviewer_thread" \
  --arg reviewer_launch_cmd "${reviewer_launch_cmd:-}" \
  --arg reviewer_worktree_sha "${reviewer_worktree_sha:-}" \
  --arg goal_md_sha "$goal_md_sha" \
  --arg verdict "$verdict" \
  --arg aggregate "$aggregate" \
  --arg src "$src" \
  --argjson must_fix "$must_fix_json" \
  --argjson should_fix "$should_fix_json" \
  --argjson new_rules "$new_rules_json" \
  --argjson delta "$delta_json" \
  --argjson runtime "$runtime_json" \
  --arg reviewer_name "codex-reviewer" \
  '{
    round: $round,
    type: $type,
    ts: $ts,
    reviewer_name: $reviewer_name,
    reviewer_pid: $reviewer_pid,
    reviewer_thread_id: $reviewer_thread,
    reviewer_launch_cmd: $reviewer_launch_cmd,
    reviewer_worktree_sha: $reviewer_worktree_sha,
    goal_md_sha: $goal_md_sha,
    verdict: $verdict,
    aggregate: ($aggregate | tonumber? // null),
    delta_vs_baseline: $delta,
    must_fix: $must_fix,
    should_fix: $should_fix,
    new_rules_proposed: $new_rules,
    runtime_evidence: $runtime,
    source_file: $src,
    orchestrator_arbitration: null
  }' >> "$JSONL"

# v4: 同时为每个 extra reviewer 写一行 JSONL
if [[ "$TYPE" == "final-review" ]]; then
  EXTRAS_DIR="$TASK_DIR/reviews/round-${ROUND}/extras"
  if [[ -d "$EXTRAS_DIR" ]]; then
    for extra_md in "$EXTRAS_DIR"/*.md; do
      [[ -f "$extra_md" ]] || continue
      extra_reviewer_name=$(basename "$extra_md" .md)
      extra_verdict=$(awk '/^## Verdict/{flag=1;next} /^## /{flag=0} flag && NF>0 {print tolower($1); exit}' "$extra_md" 2>/dev/null)
      [[ -z "$extra_verdict" ]] && extra_verdict="n/a"
      # 用 [[:space:]] 替代 \s（BSD 兼容），抓 "Aggregate: X.X" 内联格式
      extra_agg=$(grep -oE "Aggregate:[[:space:]]*[0-9.]+" "$extra_md" 2>/dev/null | head -1 | awk '{print $2}' || echo "")

      jq -n \
        --arg round "$ROUND" \
        --arg type "extra-review" \
        --arg ts "$ts" \
        --arg reviewer_name "$extra_reviewer_name" \
        --arg verdict "$extra_verdict" \
        --arg aggregate "$extra_agg" \
        --arg src "$extra_md" \
        '{
          round: $round,
          type: $type,
          ts: $ts,
          reviewer_name: $reviewer_name,
          verdict: $verdict,
          aggregate: ($aggregate | tonumber? // null),
          source_file: $src
        }' >> "$JSONL"
    done
  fi
fi

# 更新 INDEX.md
{
  echo "# Review Audit Index — $TASK_ID"
  echo
  echo "| Round | Type | Reviewer | Verdict | Aggregate | TS |"
  echo "|---|---|---|---|---|---|"
  for f in "$AUDIT_DIR"/round-*.jsonl; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
      r=$(echo "$line" | jq -r '.round')
      t=$(echo "$line" | jq -r '.type')
      n=$(echo "$line" | jq -r '.reviewer_name // "-"')
      v=$(echo "$line" | jq -r '.verdict')
      a=$(echo "$line" | jq -r '.aggregate')
      ts=$(echo "$line" | jq -r '.ts')
      echo "| $r | $t | $n | $v | $a | $ts |"
    done < "$f"
  done
} > "$INDEX"

echo "audit recorded: $JSONL"
