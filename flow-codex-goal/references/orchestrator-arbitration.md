# Orchestrator Arbitration — Step 2.4 仲裁逻辑细则

SKILL.md Step 2.4 引用本文件。orchestrator 被 `.review-pending` 唤醒后按此处逻辑跑。

---

## 1. 单 reviewer 仲裁（无 extra_reviewers 时退化路径）

```python
review = read("reviews/round-N/REVIEW.md")
goal = read("GOAL.md")

if review.verdict == "fail":
    arbitration = []
    for must_fix in review.must_fix:
        # 关键仲裁规则：黑名单优先级 > reviewer Must Fix
        if must_fix.file in goal.non_goals:
            arbitration.append({
                "must_fix_idx": must_fix.idx,
                "decision": "overridden",
                "reason": f"file in GOAL.md Non-goals: {must_fix.file}"
            })
        else:
            arbitration.append({"must_fix_idx": must_fix.idx, "decision": "accepted"})

    # 写 review-audit/round-N.jsonl 含完整仲裁记录
    write_audit(round=N, review=review, arbitration=arbitration)

    if all(a.decision == "overridden" for a in arbitration):
        # reviewer 提的 Must Fix 全在黑名单 → 视同 pass，进 Phase 3
        proceed_to_phase_3()
    else:
        # 把 accepted Must Fix 写回 STATUS.md "Next Action"
        # 退回 Goal Codex 修，回 Step 1.1
        retry()

elif review.verdict == "pass":
    # snapshot：分数创新高才打 tag
    if review.aggregate > read_highest_score():
        git_tag(f"snapshot-final-r{N}-{review.aggregate}")
    write_audit(round=N, review=review, arbitration=[])
    proceed_to_phase_3()

# 连续 N 轮（默认 3）不涨分 → 强制回退到最高分 snapshot
if no_improvement_count() >= 3:
    highest_tag = read_highest_tag()
    notify_human(f"3 轮不涨分，最高分在 {highest_tag}，回退？")
    if human_approves():
        git_checkout(highest_tag)
        proceed_to_phase_3()
```

---

## 2. 多 reviewer 仲裁（GOAL.md 含 extra_reviewers 时主路径）

```python
codex_review = read("reviews/round-N/REVIEW.md")
extra_reviews = [read(f"reviews/round-N/extras/{r}.md")
                 for r in read_extra_reviewers_from_goal()]
all_reviews = [codex_review] + extra_reviews

# 1. 仲裁规则（默认 AND-pass）
arbitration_rule = read_goal_field("arbitration_rule") or "AND-pass"

# 2. 黑名单仲裁（与单 reviewer 路径一致，对每个 reviewer 的 must_fix 都过滤）
for review in all_reviews:
    for must_fix in review.must_fix:
        if must_fix.file in goal.non_goals:
            mark_overridden(review, must_fix, reason="non-goals")

# 3. 合并 verdict
overall_verdict = apply_arbitration(all_reviews, rule=arbitration_rule)
# AND-pass: 所有 reviewer 都 pass（含 override 后视同 pass）→ pass
# 任一 fail → retry（把所有 reviewer 的 must_fix 合并写回 STATUS.md）

# 4. snapshot 用几何平均（强调"两边都好"，避免一边极高一边极低也通过）
overall_aggregate = geometric_mean([r.aggregate for r in all_reviews if r.aggregate])

# 5. 写 audit 含所有 reviewer
write_audit(round=N, all_reviews=all_reviews, arbitration=...)
```

四种 `arbitration_rule`（AND-pass / OR-pass / weighted-avg / hard-rule-override）详见
`reviewer-arbitration.md`。

---

## 3. 关键规则速查（与 SKILL.md Decision Rules 一致）

- **黑名单优先 reviewer Must Fix**：reviewer 要拆 `Non-goals` 文件 → orchestrator 拒，写 audit
- **3 轮 review fail 上限**：超出 → 强制终止 Goal Codex + alert（watcher exit 2）
- **3 轮不涨分**：回到历史最高分 snapshot tag（不是最后一轮）
- **PASS 但低于最高分**：不自动回滚，但保留快照让人类选
- **多 reviewer 仲裁**：默认 **AND-pass**（所有 reviewer 都 pass 才整体 pass）
- **几何平均**：multi-reviewer aggregate = `(r1.agg * r2.agg * ... * rN.agg) ** (1/N)`

---

## 4. retry 时把 must_fix 注入 Goal Codex

把 accepted must_fix（含跨 reviewer 合并后的去重清单）写回
`.agent/tasks/<id>/STATUS.md` 的 `Next Action` 段：

```md
## Next Action (round-(N+1))
- [reviewer codex] must_fix #2: <file>:<line> <description>
- [director-design] must_fix #1: popup 关闭按钮 hover 无反馈 → 加 hover 状态
- [director-design] must_fix #2: 错误提示文案被截断 → 加 word-break
```

Goal Codex 下次唤醒读 `Next Action` 段后开始修。watcher 检测到新 commit / milestone
后触发 round-(N+1)。
