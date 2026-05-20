# Manual Rerun Prompts（手动重跑 reviewer 模板）

> 当 watcher 死了 / extra reviewer 漏跑 / 你需要在 Phase 2 之外手动重做一轮 review 时用。
> 4 个 copy-paste 模板：baseline 重跑 / 内置 Reviewer Codex 重跑 / director-design 重跑 / director-promote 重跑。
> 每个模板里 `<占位符>` 替换成实际值即可。

---

## 通用前置（每个模板共用）

```bash
TASK_ID="<your-task-id>"                       # e.g. 20260519-194500-aibm-promo
WORKTREE="<absolute path to your worktree>"    # e.g. /Users/me/Documents/projects/foo-goal-XX
TASK_DIR=".agent/tasks/$TASK_ID"
ROUND=<N>                                       # 当前重跑的轮数（用于 reviews/round-$ROUND/）

cd "$WORKTREE"
mkdir -p "$TASK_DIR/reviews/round-$ROUND/extras"

# 重要：用绝对路径调 codex，避免 PATH 被任何包装抹掉
CODEX=$(command -v codex)
```

---

## 模板 1：Baseline 评分（Phase 0.3 重跑）

适用场景：BASELINE.md 没生成 / orchestrator 当过 reviewer / 想重跑基线。

```bash
PROMPT=$(mktemp -t baseline.XXXXXX.txt)
cat > "$PROMPT" <<EOF
You are an INDEPENDENT baseline scorer for task "$TASK_ID". Goal Codex has NOT started yet.
Score the CURRENT state of the codebase, BEFORE any modifications.

Confirm independence: log your pid; you are NOT the orchestrator session.

== Allowed Inputs ==
- $TASK_DIR/GOAL.md
- $TASK_DIR/EVAL.md
- $TASK_DIR/PLAN.md
- public/<deliverable-dir>/ (if exists, likely empty since task hasn't started)
- AGENTS.md / README.md / brand or design context files
- source files (read-only)

== Forbidden ==
- Anything related to Goal Codex (not started yet)
- STATUS.md / ISSUES.md

== Steps ==
1. Inventory: count existing deliverables (expected ~0)
2. Brand/spec context: verify reference docs are readable
3. Score N dimensions on 1-5 scale (NOT 1-10):
   <list dimensions matching your GOAL.md custom_dimensions + base 4: Correctness/Maintainability/UX/Risk>
4. Compute geometric mean aggregate

Write to: $TASK_DIR/BASELINE.md

Format (concise; target < 2 min):

# Baseline: $TASK_ID
## Timestamp
<UTC ISO>
## Reviewer Identity
- reviewer_pid: <your pid>
- launch_cmd: codex exec
## Inventory
- deliverable dir exists: yes|no
- artifacts present: N / <expected>
## Rubric Scores (1-5)
- <dim 1>: N — reason
- <dim 2>: N — reason
...
## Aggregate
- geometric_mean: X.XX
## Self-check
- [x] reviewer_pid != orchestrator_pid
- [x] 1-5 scale used
- [x] Did not read STATUS.md / future artifacts
EOF

"$CODEX" exec \\
  --skip-git-repo-check \\
  --dangerously-bypass-approvals-and-sandbox \\
  --cd "$WORKTREE" \\
  < "$PROMPT" > "$TASK_DIR/logs/baseline-rerun.log" 2>&1 &
BASELINE_PID=$!
echo "baseline_pid=$BASELINE_PID (orchestrator_pid=$$)"

# 等待 + 5min 超时（perl portable）
perl -e 'alarm 300; waitpid('"$BASELINE_PID"', 0)' || kill -9 $BASELINE_PID 2>/dev/null

ls -la "$TASK_DIR/BASELINE.md" && head -20 "$TASK_DIR/BASELINE.md"
rm -f "$PROMPT"
```

**关键点**：
- `--dangerously-bypass-approvals-and-sandbox` 必须加，否则 BASELINE.md 写入被拦
- 1-5 评分（反复强调，否则模型会自作主张改 1-10）
- 显式声明 reviewer_pid != orchestrator_pid

---

## 模板 2：内置 Reviewer Codex 重跑（Phase 2 后手动 retry）

适用场景：watcher 的 final review 失败 / REVIEW.md 没产生 / 想换 round 重新审。

```bash
PROMPT=$(mktemp -t internal-r.XXXXXX.txt)
cat > "$PROMPT" <<EOF
You are the INDEPENDENT internal Reviewer Codex for round-$ROUND of task "$TASK_ID".

After previous rounds: <一行描述上轮做了什么修复>

Confirm independence; log your pid.

== Allowed Inputs ==
- $TASK_DIR/GOAL.md
- $TASK_DIR/EVAL.md
- $TASK_DIR/BASELINE.md
- $TASK_DIR/REVIEWER-PLAN.md（如果存在）
- public/<deliverable-dir>/ (read file structure + sizes via sips/file)
- design/<spec>.md (if you have one)
- git diff --stat main

== Forbidden ==
- STATUS.md / ISSUES.md / logs/
- 任何 round-1..$((ROUND - 1))/ 历史 review 报告（防止锚定）

== Your Dimensions (1-5 scale, NOT 1-10) ==
<列出本 reviewer 负责的维度，来自 REVIEWER-PLAN.md。例如：>
1. Correctness — file/spec compliance
2. Maintainability — code/doc quality
3. Brand Consistency — color/font/logo
4. Layout Stability — sips dimension checks
5. Risk — scope clean, no out-of-scope diffs

== Steps ==
1. Run: find public/<dir> -type f | wc -l
2. Spot check >= 5 files
3. wc -l <spec>.md
4. git diff --stat main → verify only allowed paths
5. Score each dimension with one-line justification

== Output ==

Write to: $TASK_DIR/reviews/round-$ROUND/REVIEW.md

# Review: round-$ROUND (internal Reviewer Codex)
## Reviewer Identity
- reviewer_pid: <pid>
- launch_cmd: codex exec (full PATH, no env -i)
- ts: <ISO UTC>
## Verdict
pass | fail
## Dimensions (1-5)
- <dim 1>: N — reason
- ...
## Aggregate
N.NN (geometric mean)
## Must Fix
- item or "none"
## Should Fix
- item or "none"

Target < 3 min.
EOF

"$CODEX" exec \\
  --skip-git-repo-check \\
  --dangerously-bypass-approvals-and-sandbox \\
  --cd "$WORKTREE" \\
  < "$PROMPT" > "$TASK_DIR/reviews/round-$ROUND/codex.log" 2>&1 &
RPID=$!
echo "$RPID" > "$TASK_DIR/reviews/round-$ROUND/reviewer.pid"
echo "internal reviewer pid=$RPID (orchestrator pid=$$)"

# 等待 + 5min 超时
perl -e 'alarm 300; waitpid('"$RPID"', 0)' || kill -9 $RPID 2>/dev/null

cat "$TASK_DIR/reviews/round-$ROUND/REVIEW.md" 2>/dev/null
rm -f "$PROMPT"
```

---

## 模板 3：director-design 重跑（视觉评审，支持图片附件）

适用场景：UI 任务的 final review；watcher 的 extra reviewer 跑挂了；想让 design 真的"看到"图。

```bash
DESIGN_SKILL="$HOME/.config/skillshare/skills/_YeomanYe-skills/director-design/SKILL.md"
[[ -f "$DESIGN_SKILL" ]] || DESIGN_SKILL="$HOME/Documents/projects/skills/director-design/SKILL.md"

PROMPT=$(mktemp -t design.XXXXXX.txt)
cat > "$PROMPT" <<EOF
You are acting as **director-design** for round-$ROUND of task "$TASK_ID".

After previous rounds: <一行描述上轮修了什么，例如"移除了 .accent 装饰条 + xhs shot 上移">

Your role is defined by this SKILL.md (read fully before scoring):

=== BEGIN director-design SKILL.md ===
$(cat "$DESIGN_SKILL")
=== END director-design SKILL.md ===

== Your Task ==
Score the visual quality of the attached representative images, then write a review report.

Read for context:
- $TASK_DIR/GOAL.md
- $TASK_DIR/REVIEWER-PLAN.md
- design/<spec>.md (if exists)

You may NOT read STATUS.md / ISSUES.md / logs/ / round-1..$((ROUND - 1))/ extras/

== Your Dimensions (1-5 only, NOT 1-10) ==
<列出本 reviewer 负责的维度，来自 REVIEWER-PLAN.md 或下面默认 4 维：>
1. UX — overall visual quality, hierarchy, contrast, focus
2. AI-Slop Avoidance (visual) — no purple gradients, no generic emoji, no fake testimonials
3. 视觉吸引力 — would a real user stop scrolling?
4. 信息层级 — can you parse "what this is" in <2s?

== Output ==

Write to: $TASK_DIR/reviews/round-$ROUND/extras/director-design.md

# director-design Review: round-$ROUND
## Reviewer Identity
- reviewer_name: director-design
- reviewer_pid: <pid>
- ts: <ISO UTC>
- images_reviewed: <N> (1 per platform / sample basis)
## Verdict
pass | fail | needs-redesign
## Dimensions (1-5)
- <dim>: N — evidence from images
- ...
## Aggregate
N.NN (geometric mean)
## Must Fix
- <visual issue with file path> or "none"
## Should Fix
- <polish item> or "none"

Be honest. If images look like generic AI SaaS landing pages, drop the score.
EOF

# 选 N 张代表图（1 平台 1 张 / 或按你 sample 策略）
IMG_FLAGS=""
for f in \\
    public/promo/twitter/social-card.png \\
    public/promo/chrome_store/screenshot-1.png \\
    public/promo/xhs/card-1.png \\
    public/promo/og_favicon/og.png \\
    public/promo/product_hunt/gallery-1.png \\
    public/promo/v2ex/cover.png \\
    public/promo/sspai/cover.png \\
    public/promo/appinn/cover.png; do
  [[ -f "$f" ]] && IMG_FLAGS="$IMG_FLAGS -i $f"
done
echo "images attached: $(echo $IMG_FLAGS | wc -w | awk '{print $1/2}')"

"$CODEX" exec \\
  --skip-git-repo-check \\
  --dangerously-bypass-approvals-and-sandbox \\
  --cd "$WORKTREE" \\
  $IMG_FLAGS \\
  < "$PROMPT" > "$TASK_DIR/reviews/round-$ROUND/extras/director-design.codex.log" 2>&1 &
DPID=$!
echo "director-design pid=$DPID"

perl -e 'alarm 300; waitpid('"$DPID"', 0)' || kill -9 $DPID 2>/dev/null

cat "$TASK_DIR/reviews/round-$ROUND/extras/director-design.md" 2>/dev/null
rm -f "$PROMPT"
```

**关键点**：
- 必须把 SKILL.md 整份 inject 进 prompt（codex 默认不会自动 invoke skill）
- `--image / -i` 传图，建议每 reviewer ≤ 10 张（每平台抽 1-2 张代表图）
- 让 reviewer 在 prompt 里明确"只评本 reviewer 负责的维度"

---

## 模板 4：director-promote 重跑（宣发评审，支持图片附件）

适用场景：发布前的文案 / CTA / 平台规格 / 受众契合度评审。

```bash
PROMOTE_SKILL="$HOME/.config/skillshare/skills/_YeomanYe-skills/director-promote/SKILL.md"
[[ -f "$PROMOTE_SKILL" ]] || PROMOTE_SKILL="$HOME/Documents/projects/skills/director-promote/SKILL.md"

PROMPT=$(mktemp -t promote.XXXXXX.txt)
cat > "$PROMPT" <<EOF
You are acting as **director-promote** for round-$ROUND of task "$TASK_ID".

After previous rounds: <一行描述上轮修了什么>

Your role is defined by this SKILL.md (read fully before scoring):

=== BEGIN director-promote SKILL.md ===
$(cat "$PROMOTE_SKILL")
=== END director-promote SKILL.md ===

== Your Task ==
Score promo material quality (copy + platform compliance + CTA + audience fit).
Attached representative images let you inspect copy/CTA placement.

Read for context:
- $TASK_DIR/GOAL.md (platform list, sizes)
- $TASK_DIR/EVAL.md
- $TASK_DIR/REVIEWER-PLAN.md
- design/<spec>.md (CTA library + brand rules)
- scripts/<renderer>.js (actual copy used, if applicable)

NOT allowed: STATUS.md / ISSUES.md / logs/ / round-1..$((ROUND - 1))/ extras/

== Your Dimensions (1-5 only) ==
1. CTA Effectiveness — every image clear "what to do / install / try"
2. Platform Compliance — images match each platform's official spec (sizes + safe-areas + no clipping)
3. 文案质量 — punchy, non-generic, platform-specific voice
4. 受众契合度 — Chrome Store = English dev/PM, xhs = Chinese lifestyle, etc.
5. AI-Slop Avoidance (copy) — no "Revolutionary", "Game-changing", "Trusted by", fake numbers

== Output ==

Write to: $TASK_DIR/reviews/round-$ROUND/extras/director-promote.md

# director-promote Review: round-$ROUND
## Reviewer Identity
- reviewer_name: director-promote
- reviewer_pid: <pid>
- ts: <ISO UTC>
- images_reviewed: <N>
- copy_source: <renderer script / docs>
## Verdict
pass | fail | needs-redesign
## Dimensions (1-5)
- CTA Effectiveness: N — evidence
- Platform Compliance: N — evidence
- 文案质量: N — evidence
- 受众契合度: N — evidence
- AI-Slop Avoidance: N — evidence
## Aggregate
N.NN (geometric mean)
## Must Fix
- <copy/CTA/compliance issue with file or feature> or "none"
## Should Fix
- <polish item> or "none"
EOF

# Same image set as director-design (reuse)
IMG_FLAGS=""
for f in \\
    public/promo/twitter/social-card.png \\
    public/promo/chrome_store/screenshot-1.png \\
    public/promo/xhs/card-1.png \\
    public/promo/og_favicon/og.png \\
    public/promo/product_hunt/gallery-1.png \\
    public/promo/v2ex/cover.png \\
    public/promo/sspai/cover.png \\
    public/promo/appinn/cover.png; do
  [[ -f "$f" ]] && IMG_FLAGS="$IMG_FLAGS -i $f"
done

"$CODEX" exec \\
  --skip-git-repo-check \\
  --dangerously-bypass-approvals-and-sandbox \\
  --cd "$WORKTREE" \\
  $IMG_FLAGS \\
  < "$PROMPT" > "$TASK_DIR/reviews/round-$ROUND/extras/director-promote.codex.log" 2>&1 &
PR_PID=$!
echo "director-promote pid=$PR_PID"

perl -e 'alarm 300; waitpid('"$PR_PID"', 0)' || kill -9 $PR_PID 2>/dev/null

cat "$TASK_DIR/reviews/round-$ROUND/extras/director-promote.md" 2>/dev/null
rm -f "$PROMPT"
```

---

## 并行启动 3 个 reviewer（推荐）

```bash
# 假设上面 3 个 PROMPT 文件已准备好（INT_PROMPT / DESIGN_PROMPT / PROMOTE_PROMPT）

"$CODEX" exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox --cd "$WORKTREE" \\
  < "$INT_PROMPT" > "$TASK_DIR/reviews/round-$ROUND/codex.log" 2>&1 &
IPID=$!

"$CODEX" exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox --cd "$WORKTREE" $IMG_FLAGS \\
  < "$DESIGN_PROMPT" > "$TASK_DIR/reviews/round-$ROUND/extras/director-design.codex.log" 2>&1 &
DPID=$!

"$CODEX" exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox --cd "$WORKTREE" $IMG_FLAGS \\
  < "$PROMOTE_PROMPT" > "$TASK_DIR/reviews/round-$ROUND/extras/director-promote.codex.log" 2>&1 &
PR_PID=$!

echo "launched: internal=$IPID design=$DPID promote=$PR_PID"

# 等所有结束（5min 超时各自，3 个并行总时间 = max 单个）
done_i=0; done_d=0; done_p=0
for i in $(seq 1 90); do
  [[ $done_i -eq 0 ]] && ! kill -0 $IPID 2>/dev/null && { echo "internal done"; done_i=1; }
  [[ $done_d -eq 0 ]] && ! kill -0 $DPID 2>/dev/null && { echo "design done"; done_d=1; }
  [[ $done_p -eq 0 ]] && ! kill -0 $PR_PID 2>/dev/null && { echo "promote done"; done_p=1; }
  [[ $done_i -eq 1 && $done_d -eq 1 && $done_p -eq 1 ]] && break
  sleep 5
done
kill -KILL $IPID $DPID $PR_PID 2>/dev/null
```

---

## 跑完之后：手动写 arbitration.md

```bash
# 取 3 个 reviewer 的 aggregate，几何平均
GEO=$(node -e "
const a = [
  $(grep -oE 'Aggregate[^0-9]+[0-9.]+' $TASK_DIR/reviews/round-$ROUND/REVIEW.md | head -1 | grep -oE '[0-9.]+'),
  $(grep -oE 'Aggregate[^0-9]+[0-9.]+' $TASK_DIR/reviews/round-$ROUND/extras/director-design.md | head -1 | grep -oE '[0-9.]+'),
  $(grep -oE 'Aggregate[^0-9]+[0-9.]+' $TASK_DIR/reviews/round-$ROUND/extras/director-promote.md | head -1 | grep -oE '[0-9.]+')
];
console.log(Math.exp(a.reduce((s,x) => s + Math.log(x), 0) / a.length).toFixed(2));
")

cat > "$TASK_DIR/reviews/round-$ROUND/arbitration.md" <<EOF
# Arbitration: round-$ROUND

## Timestamp
$(date -u +%Y-%m-%dT%H:%M:%SZ)

## Rule
AND-pass + geometric_mean

## Per-Reviewer Results
| Reviewer | Verdict | Aggregate |
|---|---|---|
| Reviewer Codex (internal) | <pass/fail> | <N.NN> |
| director-design | <pass/fail> | <N.NN> |
| director-promote | <pass/fail> | <N.NN> |

## Combined
- overall_verdict: <pass if all 3 pass else fail>
- overall_aggregate: $GEO

## Must Fix (orchestrator triage)
- <list accepted, list overridden + reasons>

## Should Fix
- <deferred polish items>
EOF
```

如果 verdict=pass + aggregate ≥ threshold → 打 snapshot：
```bash
git tag "snapshot-final-r$ROUND-$GEO"
echo "$GEO" > "$TASK_DIR/snapshots/HIGHEST_SCORE"
echo "snapshot-final-r$ROUND-$GEO" > "$TASK_DIR/snapshots/HIGHEST_TAG"
```

---

## 调试小抄

| 现象 | 检查 |
|---|---|
| `env: codex: No such file or directory` | 用 `CODEX=$(command -v codex)` + 绝对路径调用 |
| `timeout: command not found` | macOS 没 GNU timeout，改用 `perl -e 'alarm N; waitpid(PID, 0)'` 或 `( cmd & PID=$! ; sleep N && kill $PID )` |
| `patch rejected: read-only sandbox` | 加 `--dangerously-bypass-approvals-and-sandbox` |
| codex 把 1-5 改成 1-10 | prompt 里反复强调"score on 1-5 scale, do NOT rescale to 1-10" |
| reviewer 漏审某维度 | 在 prompt 里明确"only score these dimensions: [...]"，并核对覆盖性 |
| Codex 看不见 director-* skill 内容 | 必须在 prompt 里 inject 整份 SKILL.md（`=== BEGIN ... === END ===`） |
| reviewer 报告里有 "implementer says..." 类污染语 | review-prompt 里强禁这类引用；reviewer 工作在 readonly worktree 物理屏蔽 STATUS.md |
