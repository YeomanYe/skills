#!/usr/bin/env bash
# push-mockups-to-feishu.sh — 把 3 路落地页 mockup 的关键截图推到飞书
#
# 用法:
#   bash push-mockups-to-feishu.sh <task-dir> <mockup-dir-1> <mockup-dir-2> <mockup-dir-3>
#
# 触发条件:
#   - CC_SESSION_KEY 含 "feishu:" 前缀
#   - cc-connect 可用
#
# 推送内容:
#   - 每路取 screenshots/375.png + screenshots/1440.png 共 6 张
#   - 消息含 3 路 style_name + 用户回复选项
#
# 设计原则:
#   - 不超时 auto-pick（设计选择由人决定）
#   - 非飞书渠道跳过，由 orchestrator 在对话里贴路径
#   - cc-connect 失败时降级写到 STATUS.md

set -u

TASK_DIR="${1:?task-dir required}"
MOCKUP_1="${2:?mockup dir 1 required}"
MOCKUP_2="${3:?mockup dir 2 required}"
MOCKUP_3="${4:?mockup dir 3 required}"

LOG="$TASK_DIR/logs/push-mockups.log"
mkdir -p "$(dirname "$LOG")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

# 1. 检查触发条件
if [[ -z "${CC_SESSION_KEY:-}" ]]; then
  log "CC_SESSION_KEY not set; skipping feishu push"
  exit 0
fi

if [[ "$CC_SESSION_KEY" != feishu:* ]]; then
  log "CC_SESSION_KEY is not feishu (got: $CC_SESSION_KEY); skipping push"
  exit 0
fi

if ! command -v cc-connect > /dev/null 2>&1; then
  log "cc-connect not installed; skipping push"
  echo "FALLBACK: cc-connect unavailable, please paste mockup paths to user manually" >> "$TASK_DIR/STATUS.md"
  exit 0
fi

# 2. 校验 3 个 mockup 目录
for d in "$MOCKUP_1" "$MOCKUP_2" "$MOCKUP_3"; do
  [[ -d "$d" ]] || { log "ERR: mockup dir not found: $d"; exit 1; }
  [[ -f "$d/screenshots/375.png" ]] || { log "ERR: missing $d/screenshots/375.png"; exit 1; }
  [[ -f "$d/screenshots/1440.png" ]] || { log "ERR: missing $d/screenshots/1440.png"; exit 1; }
done

# 3. 读取每路的 style_name（从 meta.json）
get_style_name() {
  local meta="$1/meta.json"
  if [[ -f "$meta" ]]; then
    jq -r '.style_name // "未命名风格"' "$meta" 2>/dev/null || echo "未命名风格"
  else
    echo "未命名风格"
  fi
}

STYLE_1=$(get_style_name "$MOCKUP_1")
STYLE_2=$(get_style_name "$MOCKUP_2")
STYLE_3=$(get_style_name "$MOCKUP_3")

log "Pushing 3 mockups to feishu: '$STYLE_1' / '$STYLE_2' / '$STYLE_3'"

# 4. 拼消息文案
MESSAGE=$(cat <<EOF
📐 落地页 3 路独立 mockup 已就绪（mobile + desktop）

方向 1: $STYLE_1
方向 2: $STYLE_2
方向 3: $STYLE_3

请回复：
  · "选 1" / "选 2" / "选 3"  → 选定方向进入实现
  · "都不行 重做"             → 派新一轮 3 路
  · "方向 N 改 X"             → 派该路微调

⚠️ 不会超时，慢慢看不着急。
EOF
)

# 5. cc-connect 发送（消息 + 6 张截图）
cc-connect send \
  --message "$MESSAGE" \
  --image "$MOCKUP_1/screenshots/375.png" \
  --image "$MOCKUP_1/screenshots/1440.png" \
  --image "$MOCKUP_2/screenshots/375.png" \
  --image "$MOCKUP_2/screenshots/1440.png" \
  --image "$MOCKUP_3/screenshots/375.png" \
  --image "$MOCKUP_3/screenshots/1440.png" \
  2>>"$LOG"

# 幂等 marker：基于 3 路 mockup 路径生成稳定 hash，避免重跑追加多段
MARKER_HASH=$(echo -n "$MOCKUP_1|$MOCKUP_2|$MOCKUP_3" | shasum -a 256 | awk '{print $1}' | head -c 12)
MARKER_TAG="<!-- pending-decision-mockup-$MARKER_HASH -->"

# 如果已有相同 marker，不重复写
if grep -q "$MARKER_TAG" "$TASK_DIR/STATUS.md" 2>/dev/null; then
  log "STATUS.md already has marker $MARKER_TAG; skip duplicate write"
else
  if [[ $? -eq 0 ]]; then
    log "Pushed 6 screenshots + message to feishu OK"
    cat >> "$TASK_DIR/STATUS.md" <<EOF

$MARKER_TAG
## Pending Decision (落地页 mockup 选择)
- TS: $(date '+%Y-%m-%d %H:%M:%S')
- 3 路 mockup:
  - 1: $MOCKUP_1 ($STYLE_1)
  - 2: $MOCKUP_2 ($STYLE_2)
  - 3: $MOCKUP_3 ($STYLE_3)
- 已推送到飞书等用户回复
- 不超时 auto-pick；用户回复后 orchestrator 才继续 Step 3.3
EOF
  else
    log "ERR: cc-connect send failed (recorded)"
    cat >> "$TASK_DIR/STATUS.md" <<EOF

$MARKER_TAG
## Pending Decision (落地页 mockup 选择) — 飞书推送失败
- TS: $(date '+%Y-%m-%d %H:%M:%S')
- 请手动查看 mockup:
  - 1: $MOCKUP_1 ($STYLE_1)
  - 2: $MOCKUP_2 ($STYLE_2)
  - 3: $MOCKUP_3 ($STYLE_3)
EOF
    exit 1
  fi
fi
