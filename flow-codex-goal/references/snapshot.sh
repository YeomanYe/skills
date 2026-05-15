#!/usr/bin/env bash
# snapshot.sh — 分数创新高时打 snapshot tag，用于最高分回退
#
# 用法:
#   ./snapshot.sh <task-id> <round-name> <aggregate-score>
#
# 输出:
#   created  → 新打了 tag（分数创新高）
#   skipped  → 分数未创新高，没打 tag
#   error    → 出错（不创建 tag）
#
# 副作用:
#   分数创新高时:
#     - git tag snapshot-<round>-<score>
#     - 写 .agent/tasks/<id>/snapshots/HIGHEST_SCORE
#     - 写 .agent/tasks/<id>/snapshots/HIGHEST_TAG
#     - 写 .agent/tasks/<id>/snapshots/HISTORY.jsonl 一行
#
# 不会自动 git checkout——回退需要 orchestrator 决定。

set -u

TASK_ID="${1:?task-id required}"
ROUND="${2:?round name required}"
SCORE="${3:?aggregate score required (float)}"

TASK_DIR=".agent/tasks/$TASK_ID"
SNAP_DIR="$TASK_DIR/snapshots"
mkdir -p "$SNAP_DIR"

HIGHEST_FILE="$SNAP_DIR/HIGHEST_SCORE"
HIGHEST_TAG_FILE="$SNAP_DIR/HIGHEST_TAG"
HISTORY="$SNAP_DIR/HISTORY.jsonl"

# 取当前最高分
CUR_HIGHEST=$(cat "$HIGHEST_FILE" 2>/dev/null || echo 0)

# bc 比较浮点
IS_NEW_HIGH=$(awk -v c="$SCORE" -v h="$CUR_HIGHEST" 'BEGIN{print (c > h) ? 1 : 0}')

if [[ "$IS_NEW_HIGH" != "1" ]]; then
  # 仍然记录到 HISTORY，标记 not-new-high
  echo "{\"round\":\"$ROUND\",\"score\":$SCORE,\"new_high\":false,\"ts\":\"$(date -u +%FT%TZ)\"}" >> "$HISTORY"
  echo "skipped"
  exit 0
fi

# 创新高 → 打 tag
TAG="snapshot-$ROUND-$SCORE"

# tag 已存在则跳过（同分场景可能重跑）
if git rev-parse -q --verify "refs/tags/$TAG" > /dev/null 2>&1; then
  echo "{\"round\":\"$ROUND\",\"score\":$SCORE,\"new_high\":true,\"tag\":\"$TAG\",\"note\":\"tag-exists\",\"ts\":\"$(date -u +%FT%TZ)\"}" >> "$HISTORY"
  echo "skipped"
  exit 0
fi

if ! git tag "$TAG" 2>/dev/null; then
  echo "{\"round\":\"$ROUND\",\"score\":$SCORE,\"new_high\":true,\"tag_attempted\":\"$TAG\",\"note\":\"git-tag-failed\",\"ts\":\"$(date -u +%FT%TZ)\"}" >> "$HISTORY"
  echo "error"
  exit 1
fi

echo "$SCORE" > "$HIGHEST_FILE"
echo "$TAG" > "$HIGHEST_TAG_FILE"

echo "{\"round\":\"$ROUND\",\"score\":$SCORE,\"new_high\":true,\"tag\":\"$TAG\",\"ts\":\"$(date -u +%FT%TZ)\"}" >> "$HISTORY"

echo "created"
