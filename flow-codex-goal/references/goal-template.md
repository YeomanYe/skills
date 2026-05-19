# GOAL.md 模板

> 这是 Codex Goal 长跑的"目标契约"。**写得越具体，跑飞的概率越低**。

```md
# Goal: <task-id>

## Objective
<一句话说清楚要达成什么。例如："Migrate all class components in src/legacy/ to functional components with hooks">

## Scope
**允许修改的范围**（白名单）：
- src/legacy/**
- src/components/shared/** (only if cross-cutting)

**明确不动**（黑名单）：
- src/api/auth/**
- src/api/payment/**
- migrations/**
- node_modules/**, dist/**, .next/**

## Non-goals
明确不在本次范围内：
- <例：不重写 routing 层，那是另一个任务>
- <例：不升级 React 版本>
- <例：不动测试框架>

## Acceptance Criteria
**量化、可验证**的完成条件，每条必须能通过 EVAL.md 中某条命令验证：

- [ ] grep -r "extends Component\|extends React.Component" src/legacy/ 返回空
- [ ] pnpm test 全部通过（无新增 fail）
- [ ] pnpm build 成功且 bundle size 不增加 > 5%
- [ ] git diff --stat 显示 ≥ 80% 文件位于 src/legacy/

## User Journeys
**Reviewer Codex 的 Step 4 运行时验证会逐条跑这些**。每条要描述清楚"做什么 → 期望看到什么"：

- [ ] J1: 打开 / → 应显示首页 hero + 3 个产品卡片（无 console error）
- [ ] J2: 点击产品卡片 → 跳到 /product/:id → 显示产品详情 + "加入购物车"按钮
- [ ] J3: 加入购物车 → 右上角 badge +1 → 点击 badge → 跳到 /cart 显示该商品
- [ ] J4: 触发 404（访问 /nonexistent）→ 显示自定义 404 页 + 返回按钮
- [ ] J5: 模拟离线（DevTools Network → Offline）→ 显示离线 fallback 而非白屏

## Task Metadata（Phase 0 必填）

```yaml
is_ui_task: false              # true 时激活 UI 截图协议 + 状态走查 + 同分硬规则裁决（详见 references/ui-review-checklist.md）
risk_class: medium             # low | medium | high  → 决定 Step 3.1 orchestrator 自跑验证的力度
run_mode: CLI-YOLO             # CLI-YOLO | CLI-EXEC | SUBAGENT  → Phase 0.0 探测得到，全程不变
```

## Goal-Attainment Mode
**何时算"达成"**。Phase 0.1 Step 2 已确认，写下来供 watcher 和 reviewer 解析。

```yaml
mode: regression-prevention   # threshold | no-improvement-N | regression-prevention | hybrid
threshold: 4.0                 # 仅 mode=threshold/hybrid 时生效，综合分数下限
no_improvement_n: 3            # 仅 mode=no-improvement-N/hybrid 时生效，连续 N 轮不升即停
baseline_dimensions:           # 仅 mode=regression-prevention/hybrid 时生效，任一维度低于 baseline 即停
  - correctness
  - maintainability
  - ux
  - risk
```

## Extra Reviewers（Phase 0.1 Step 5，可选注册）

声明在 Step 2.3 与内置 Reviewer Codex **并列启动**的额外 reviewer（如 `director-design` 做 UI 视觉专项审）。

### 极简 schema（推荐）

```yaml
extra_reviewers:
  # 4 个已实现 director-*(任选,按 references/role-router.md 路由表自动建议):
  - director-design       # UI 视觉审(is_ui_task: true 时自动建议)
  - director-frontend     # JSX 代码审(UI 任务双 reviewer 之一,或纯代码任务)
  - director-promote      # 宣发材料 9 维 audit(release notes / 多平台发布素材)
  - director-ops          # 装卸/环境配置 7 维流程 audit(install/uninstall 任务)
  # 未来:director-security / director-architect / director-pm / director-qa
```

### 4 角色含义速查

| Reviewer | 审什么 | 何时接 |
|---|---|---|
| **director-design** | 视觉(信息层级/布局/字体/对比/产品气质 等 9 维) | UI 任务 + 有截图证据 |
| **director-frontend** | JSX 代码(组件边界/层级归属/本地规范/API 一致 等 9 维) | UI 任务 + 纯前端代码任务 |
| **director-promote** | 宣发材料(标题钩子/受众匹配/图片合规/CTA/Native Feel 等 9 维) | release notes / 多平台发布 |
| **director-ops** | 装卸流程(环境探测/资料可信/计划可执行/验证/知识库 等 7 维) | 装/卸/setup/install 任务 |

完整路由规则(任务信号 → 角色映射 + 探测命令)见 `references/role-router.md`。

### 详细 schema（按需扩展）

```yaml
extra_reviewers:
  - name: director-design
    when: is_ui_task          # 条件触发（可选；不写 = 始终启用）
    mode: audit               # 让该 reviewer 跑哪个 mode（可选；默认按 reviewer 自己 SKILL.md）
    arbitration_weight: 1.0   # 仲裁权重（仅 weighted-avg 模式生效）
    checks:                   # 该 reviewer 负责检查的维度（Phase 0.1 第 5 项用户确认后写入）
      - UX
      - Layout Stability
  - name: director-frontend
    when: is_ui_task          # UI 任务双 reviewer(视觉师 + 工程师)
    mode: audit
    checks:                   # 该 reviewer 负责检查的维度
      - Correctness
      - Maintainability

# 仲裁规则（可选）
arbitration_rule: AND-pass    # AND-pass（默认）| OR-pass | weighted-avg | hard-rule-override
```

### `checks` 字段（reviewer 检查维度声明）

- 每个 extra reviewer 用 `checks:` 列出它在 EVAL.md 哪些维度上打分。
- 内置 Reviewer Codex 不在此段（它必跑），其 `checks` 默认 = `Correctness / Maintainability / Risk` + 非 UI 扩展维度，
  在 `REVIEWER-PLAN.md` 表里显式列出。
- **覆盖性硬规则**：EVAL.md 的每个评分维度必须至少被一个 reviewer 的 `checks` 认领，不允许"无人检查的维度"。
- `checks` 由 Phase 0.1 第 5 项的 Reviewer Plan 确认表经用户确认后写入，详见 `references/reviewer-arbitration.md`。

### 默认行为

- **不写 extra_reviewers** = 只跑内置 Reviewer Codex（向下兼容 v3）；它仍要在 `REVIEWER-PLAN.md` 声明 checks
- **arbitration_rule 默认 AND-pass**：所有 reviewer 都 pass 才整体 pass
- **snapshot 用几何平均**：避免一边极高一边极低也通过

详见 `references/reviewer-arbitration.md`。

## Custom Score Dimensions（Phase 0.1 Step 4 由 orchestrator 建议 + 人类追加）

参考 `references/score-rubric-extensions.md`。例：

```yaml
custom_dimensions:
  - name: layout_stability        # UI 任务推荐
    description: "反馈、header、footer、滚动区域是否稳定"
    range: [1, 5]
  - name: small_popup_density     # UI 任务推荐
    description: "小空间紧凑但不拥挤"
    range: [1, 5]
  - name: state_consistency       # UI 任务推荐
    description: "数量承诺与可见内容一致"
    range: [1, 5]
```

## Stop Conditions
**任一命中必须停止并写入 STATUS.md，等待人类决策**：

- 连续 3 次 `pnpm test` 失败且不能 root cause
- 修改文件 > 50 个
- token 用量 > 500K
- 需要修改 src/api/auth/ 或 src/api/payment/
- 需要破坏性 git 操作（rebase / reset --hard / push --force）
- 发现需求互相冲突（PLAN.md 第 N 步与 Acceptance Criteria 第 M 条矛盾）
- 进入了 Non-goals 范围

## Budget
**硬上限**（超出立即停）：

- Files modified: ≤ 50
- Token consumption: ≤ 500,000
- Wall clock time: ≤ 4 hours
- Failed verification rounds: ≤ 3

## Workflow Rules
Goal Codex 执行时**必须遵守**：

1. 每个 milestone 完成后：
   - 更新 STATUS.md（含 timestamp / phase / step / next action）
   - **写入一行 `MILESTONE: <name>`**（watcher 监这一行触发 mini-review + IM 推送）
   - 运行 EVAL.md 中定义的验证命令
   - 把验证输出 append 到 logs/verify.log
2. 验证失败时：
   - 先分析 root cause（写入 ISSUES.md / Risks 段）
   - 再修复
   - 不要直接重试
3. 计划外发现：
   - 写入 ISSUES.md
   - 不要扩大范围
4. 文件操作禁忌：
   - 不要 `git add .`（必须显式列文件）
   - 不要 `git commit`（commit 由 orchestrator agent 通过 clean-commit 完成）
   - 不要 `git push`
   - 不要提交 dist/、node_modules/、build artifacts
5. 人类反馈：
   - 每个 milestone 开始前先 grep STATUS.md 是否有新的 `## Human Feedback` 段
   - 有则按反馈调整 PLAN，再继续
6. 完成判定：
   - 所有 Acceptance Criteria 都打勾
   - 所有 User Journeys 自测可通过（截图存到 .agent/tasks/<task-id>/screenshots/self/）
   - STATUS.md 末尾写入 `GOAL_DONE` 标记（必须是这个字符串，不能改）
   - 等待外部 review，不要自宣告完成

## References
Goal Codex 必须先读：
- 项目根 AGENTS.md（项目规范）
- .agent/tasks/<task-id>/PLAN.md（执行步骤）
- .agent/tasks/<task-id>/EVAL.md（验证命令）
- .agent/tasks/<task-id>/BASELINE.md（当前系统基线分数，避免越改越差）
```
