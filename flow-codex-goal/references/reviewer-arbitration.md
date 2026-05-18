# Reviewer Arbitration — 多 reviewer 注册 + 仲裁机制

flow-codex-goal v4 引入的 "extra_reviewers 通用注册框架"，让 Reviewer Codex 之外
可挂载任意多个 director-* 角色作为额外审计员。

---

## 核心模型

```
Step 2.3 Final Review
  ├─ 内置 Reviewer Codex（**必跑**，写死流程内）— 代码 / 测试 / 合规 / 4 维 rubric
  └─ Extra Reviewers（**按 GOAL.md 注册**，并列启动）
       ├─ director-design（is_ui_task=true 时建议）— UI 视觉 9 维度
       ├─ director-security（未来）— auth/支付/加密类
       ├─ director-architect（未来）— 大型重构/数据模型
       └─ ... 更多 director-*
```

所有 reviewer **并列启动**（subagent / codex exec），各自独立报告，由
Step 2.4 orchestrator 按 `arbitration_rule` 合并 verdict。

---

## 注册方式

GOAL.md 加 `extra_reviewers:` 段（详见 `goal-template.md`）：

```yaml
extra_reviewers:
  - director-design        # 极简：默认 mode + weight 1.0

# 或详细：
extra_reviewers:
  - name: director-design
    when: is_ui_task       # 条件触发（不写 = 始终）
    mode: audit            # reviewer 内部模式
    arbitration_weight: 1.0

arbitration_rule: AND-pass   # 可选，默认 AND-pass
```

**不写 extra_reviewers = 只跑内置 Reviewer Codex**（向下兼容 v3）。

---

## 派工机制

watcher.sh 在 Step 2.3.2 调 `launch_extra_reviewers()`：

```bash
# 伪代码（实际实现见 watcher.sh）
launch_extra_reviewers() {
  local round=$1
  local extras=$(yq '.extra_reviewers[]' "$TASK_DIR/GOAL.md")
  local pids=()

  for reviewer_name in $extras; do
    # 评估 when 条件（若有）
    if ! eval_when_condition "$reviewer_name"; then continue; fi

    # 派 subagent，**显式调用** reviewer skill
    bash "$SCRIPT_DIR/launch-extra-reviewer.sh" \
      "$TASK_ID" "$round" "$reviewer_name" &
    pids+=($!)
  done

  # collect-all：所有 reviewer 都返回，单路失败不阻塞
  wait "${pids[@]}" || log "some extra reviewer failed (non-blocking)"
}
```

**派工 prompt 模板**（在 SKILL.md Step 2.3.2 段已展示，subagent prompt 必须含
"显式调用 X skill" 硬规则——subagent 默认不会主动用 skill）。

输出路径：
- 内置：`reviews/round-N/REVIEW.md`
- Extra：`reviews/round-N/extras/<reviewer-name>.md`

---

## 多 Reviewer 协同细则(2-4 个 AND-pass)

`flow-codex-goal` 2026-05 升级后,默认路由可同时接 2-4 个 director-* reviewer。
对 AND-pass 默认规则的实际影响:

| reviewer 数 | 整体 pass 概率(假设单 reviewer 80% pass)| 典型场景 |
|---|---|---|
| 1(只 codex-reviewer)| 80% | 纯逻辑代码任务 |
| 2(codex + 1 director-*)| 64% | 纯前端代码 / 宣发 / 装卸 |
| **3(codex + design + frontend)** | **51%** | **UI 视觉任务双 reviewer 默认** |
| 4(codex + 3 director-*)| 41% | 混合任务(罕见,建议拆) |

**含义**:接 reviewer 越多,过 round 越严。1-2 reviewer 是甜点,3+ 通常说明任务该拆。

### 推荐配置

| 任务类型 | reviewer 配置 | arbitration_rule |
|---|---|---|
| 纯逻辑代码 | 只 codex-reviewer | AND-pass(平凡) |
| 纯前端 / 宣发 / 装卸 | codex + 1 director-* | AND-pass |
| UI 视觉任务 | codex + director-design + director-frontend | AND-pass(默认,严格)|
| 品牌关键页(MUST 不出错) | codex + design + frontend + (可选 director-promote 审 release 文案) | AND-pass + hard-rule-override(图片合规 1 票否决) |

### 不要做什么

- ❌ **AND-pass + 3+ reviewer 抱怨"太严"** → 应该拆任务,不应该改成 OR-pass(放低质量门 = 把问题留到生产)
- ❌ **加 reviewer 但不给它探测命令信号支撑** → 路由器靠信号路由,不靠 LLM 猜测;无信号不该路由
- ❌ **同一 reviewer 加 2 次**(重复浪费 round 资源)
- ❌ **推未实现的 reviewer**(director-security/architect 还没建,watcher launch 会失败)

详细路由规则见 `references/role-router.md`。

## 4 种仲裁规则

### 1. AND-pass（默认，推荐）

所有 reviewer 都 pass 才整体 pass。任一 fail / needs-redesign → 整体 fail。

```python
def and_pass(reviews):
    return all(r.verdict == "pass" for r in reviews)
```

适合：严格质量门 / 多角度都要 pass 才算交付

### 2. OR-pass（宽松）

任一 reviewer pass 即整体 pass。

```python
def or_pass(reviews):
    return any(r.verdict == "pass" for r in reviews)
```

适合：reviewer 之间会冲突 / 只需一边过即可 / **不推荐作默认**

### 3. weighted-avg（加权）

按 reviewer 的 `arbitration_weight` 加权 aggregate 分数，超过阈值（默认 4.0）即 pass。

```python
def weighted_avg(reviews, threshold=4.0):
    weights = [r.weight for r in reviews]
    scores = [r.aggregate for r in reviews]
    weighted = sum(w * s for w, s in zip(weights, scores)) / sum(weights)
    return weighted >= threshold
```

适合：reviewer 重要性不同 / 需要细调质量门 / **不推荐新手使用**

### 4. hard-rule-override（一票否决）

优先级最高的 reviewer 可一票否决其他 reviewer。优先级 = GOAL.md `extra_reviewers` 列表顺序（越前优先级越高），内置 Reviewer Codex 默认最高。

```python
def hard_rule_override(reviews):
    # 任一高优先级 reviewer 给出 needs-redesign → 全体 fail
    for r in reviews:
        if r.verdict in ("needs-redesign",):
            return "fail"
    return "pass" if all(r.verdict == "pass" for r in reviews) else "fail"
```

适合：安全 / 合规场景，某个 reviewer（如 `director-security`）可一票否决整次交付。

---

## snapshot 策略（多 reviewer）

v3 用单个 reviewer 的 aggregate 比对 HIGHEST_SCORE。

v4 改用 **几何平均** 作为整体 aggregate：

```python
overall_aggregate = (r1.aggregate * r2.aggregate * ... * rN.aggregate) ** (1/N)
```

理由：几何平均强调"两边都好"——任一 reviewer 极低会拉低整体，避免一边 5/5
另一边 2/5 也算"4.0 通过"。

snapshot tag 命名：`snapshot-final-r<round>-<overall_aggregate>`

---

## 仲裁审计

`reviews/round-N/arbitration.md` 记录合并决策：

```md
# Arbitration: round-N

## Rule
AND-pass

## Reviewers
- codex-reviewer (内置)
  - verdict: pass
  - aggregate: 4.5
  - source: reviews/round-N/REVIEW.md

- director-design (extra)
  - verdict: pass-with-fixes
  - aggregate: 4.0
  - must-fix: 2 条（已合并到 STATUS.md Next Action）
  - source: reviews/round-N/extras/director-design.md

## Combined
- overall_verdict: pass-with-fixes
- overall_aggregate: 4.24（几何平均）
- snapshot_decision: skip（4.24 < HIGHEST_SCORE 4.5）

## Must-Fix 合并清单（写回 STATUS.md）
1. [director-design] popup 关闭按钮 hover 无反馈 → 加 hover 状态
2. [director-design] 错误提示文案被截断 → 加 word-break
```

每个 reviewer 的独立报告路径保留，arbitration.md 只是合并视图。

---

## 反向兼容

- v3 GOAL.md（无 extra_reviewers 字段）→ v4 watcher 跳过 extra reviewers 段，行为完全等价 v3
- v3 已存在的 reviews/round-N/REVIEW.md → v4 视为"内置 codex-reviewer 的报告"
- v3 snapshot 用单个 aggregate → v4 自动按"只有 1 个 reviewer"计算，几何平均退化为算术平均

---

## 加新 director-* reviewer 的流程

1. 该 director-* skill 必须存在且 SKILL.md 写明它支持作为 extra reviewer（即有 `audit` mode 输出符合本框架的报告格式）
2. 在 GOAL.md `extra_reviewers:` 加一行
3. watcher.sh 不需要改代码（注册机制是数据驱动）
4. 报告路径自动落到 `reviews/round-N/extras/<reviewer-name>.md`

未来加 `director-security` / `director-pm` / `director-architect` 等，**零代码改动**。

---

## 与 _shared/parallelization-template.md 的关系

extra_reviewers 派工本质是"并行编排"的一种实例，遵循 _shared 的：
- subagent 派工 prompt 必须**显式调用 skill**
- 错误恢复用 **collect-all**（一路 fail 不阻塞其他）
- reduce 用**方式 1**（各 reviewer 写独立 md 文件，orchestrator 合并仲裁）
- ROI 阈值：≥ 2 个 reviewer 时并行才划算（1 个就别用 extra_reviewers，直接用内置 Reviewer Codex）
