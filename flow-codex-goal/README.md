# flow-codex-goal

编排 Codex `/goal` 长跑任务的 orchestrator skill。把"Phase 0 契约 → baseline → Goal Codex 长跑 → milestone mini-review → final review（硬隔离 + 多 reviewer 仲裁）→ 人类签字 → commit"一条流水线串起来。

> **正文规范**：`SKILL.md`。本 README 只做入口导览 + 常用模板索引 + 故障排查。

---

## 何时用 / 何时不用

| 用 | 不用 |
|---|---|
| 任务 ≥ 2 小时、可拆步、有 acceptance criteria | 短任务 → `flow-dev-task` |
| 想"无人值守长跑" | 模糊目标 → `superpowers:brainstorming` |
| Codex CLI ≥ 0.128.0 + `goals` feature flag 启用 | 高风险代码（auth / 支付 / 加密）|
| Goal Codex / Reviewer Codex 双进程硬隔离场景 | Codex 未装或版本 < 0.128.0 |

完整准入门槛 + 用户判断权例外 → 见 `SKILL.md` "When to Use" 段。

---

## 30 秒速读：4 个 Phase

```
Phase 0: 契约门（必须人类签字）
  ├─ Step 0.0 pre-flight + run_mode 探测（CLI-YOLO / TMUX-YOLO / CLI-EXEC / SUBAGENT）
  ├─ Step 0.1 AC + Goal-Attainment Mode + Budget + Custom Rubric + Reviewer Plan
  ├─ Step 0.2 创建任务目录 + 隔离 worktree + 模板落盘
  ├─ Step 0.3 baseline 评分（独立 Reviewer Codex 跑）
  └─ Step 0.4 APPROVAL.md 签字（IM 会话用 "approve goal <id>" 关键词）

Phase 1: Execution（Goal Codex 长跑）
  ├─ Step 1.1 启动 Goal Codex（按 run_mode 分支）
  ├─ Step 1.2 启动 watcher.sh（health + boundary + inbox-poll + tmux marker）
  ├─ Step 1.3 watcher milestone 循环：runtime-evidence → mini-review → snapshot → audit → IM push
  └─ Step 1.4 orchestrator idle（只在 4 个唤醒点被叫醒）

Phase 2: Final Review（硬隔离的独立 reviewer + 多 reviewer 仲裁）
  ├─ Step 2.1 生成 review-input
  ├─ Step 2.2 创建 review-readonly worktree（核心隔离边界）
  ├─ Step 2.3 启动内置 Reviewer Codex + extra reviewers（director-design / director-promote 等）
  └─ Step 2.4 仲裁 verdict + snapshot + 最高分回退

Phase 3: Delivery
  ├─ Step 3.1 风险分层验证
  ├─ Step 3.2 人类签字
  ├─ Step 3.3 commit（基于 HIGHEST_TAG 不是 HEAD）
  └─ Step 3.4 清理
```

---

## 文件索引

### 核心契约模板（Phase 0 落盘）

| 文件 | 用途 |
|---|---|
| `references/goal-template.md` | `GOAL.md`：objective / scope / AC / mode / budget / extra_reviewers |
| `references/plan-template.md` | `PLAN.md`：分 phase 步骤 + 验证 |
| `references/eval-template.md` | `EVAL.md`：verify commands + quality gates + reviewer rubric |
| `references/stop-conditions.md` | `STOP-CONDITIONS.md`：所有停止条件清单 |
| `references/handoff-payload-template.md` | flow-dev-task → flow-codex-goal 切换的 handoff schema |

### Codex 派工 prompt

| 文件 | 用途 |
|---|---|
| `references/baseline-prompt.md` | Phase 0.3 baseline 评分（必须 `--dangerously-bypass-approvals-and-sandbox`，否则 BASELINE.md 写不进） |
| `references/goal-prompt.md` | Phase 1.1 Goal Codex 启动指令（含 marker 协议 + hard rules） |
| `references/milestone-review-prompt.md` | Phase 1.3 mini-review codex prompt |
| `references/review-prompt.md` | Phase 2.3 最终 reviewer codex prompt（4 维度 + 运行时验证） |
| **`references/manual-rerun-prompts.md`** | **当 watcher 死了 / extra reviewer 漏跑时，orchestrator 手动重启 reviewer 的 copy-paste 模板**（内置 / director-design / director-promote 三套）|

### Watcher 控制流脚本

| 文件 | 用途 |
|---|---|
| `references/watcher.sh` | 主看门狗（health + boundary + inbox-poll + tmux marker + final review + verdict-aware exit） |
| `references/health-check.sh` | 6 维度健康判定（running / done / stalled / milestone / failed / stopped） |
| `references/boundary-watch.sh` | worktree 越界守卫 |
| `references/run-mode.sh` | run mode 探测（CLI-YOLO / TMUX-YOLO / CLI-EXEC / SUBAGENT） |
| `references/snapshot.sh` | 分数创新高打 git tag |
| `references/write-audit.sh` | 写 review-audit JSONL |
| `references/score-diff.py` | baseline vs current 评分对比 + 退化判定 |
| `references/runtime-evidence.sh` | 启动项目 + 跑用户旅程 + 截图 |

### 工程规范 / 协议

| 文件 | 用途 |
|---|---|
| `references/tmux-yolo-runtime.md` | TMUX-YOLO 模式三协议（PHASE-N-DONE marker / capture-pane strip / cleanup） |
| `references/run-mode.md` | 4 种 run mode 选择规则 + 强烈建议条款 |
| `references/parallelization-template.md` | 多 subagent 并行派工模板（含显式 skill 指挥硬规则） |
| `references/reviewer-arbitration.md` | 多 reviewer 仲裁规则（AND-pass / OR-pass / weighted-avg / hard-rule-override） |
| `references/role-router.md` | 任务信号 → reviewer 角色映射表 |
| `references/score-rubric-extensions.md` | UI 任务的扩展评分维度库 |
| `references/ui-review-checklist.md` | UI 任务的状态走查 / 同分裁决硬规则 |
| `references/review-audit-schema.md` | 审计日志 JSONL schema |
| `references/codex-goal-setup.md` | Codex CLI 配置 + feature flag 启用 |
| `references/constitution.md` | 跨 skill 通用价值观 / 安全 / 身份层（always-follow） |

---

## Watcher Exit Code 速查（修复后）

| code | 含义 | orchestrator 行为 |
|---|---|---|
| **0** | final verdict=pass + 所有 quality gate 过 | 进 Phase 3（人类签字 + commit） |
| **1** | boundary violation / task failed | 上报人类（含诊断包 diagnostics/） |
| **2** | review verdict=fail **连续 3 轮**（命中 stop-conditions.md S-2） | 必须上报人类，**不再 auto-retry**（abort / handoff / rescope 4 选 1） |
| **3** | review verdict=fail **未达 3 轮上限** | **自动 retry**：① 读 `arbitration.md` ② 仲裁 must_fix ③ 派给 Goal Codex 修 ④ 重启 watcher 进下一 round。**不许问用户** |
| **4** | verdict 解析失败（reviewer 全部 missing 等异常） | 人类手动检查 `reviews/round-N/` |

详细映射 + 禁止行为 → `SKILL.md` "Watcher Exit Code → Orchestrator 行为映射" 段。

---

## 故障排查

### 症状：`Watcher exiting (task complete)` 但实际 reviewer 全失败

**根因**：旧版 watcher（≤ 2026-05-19）看到 STATUS.md `GOAL_DONE` 就退出，忽略 arbitration verdict。
**修法**：升级到 ≥ commit `8766a93`。修复后 watcher 按 verdict 给 exit code 0/2/3/4。

### 症状：所有 extra reviewer 启动后立即挂

**根因**：macOS 默认没有 GNU `timeout`，旧版 `timeout 600 codex ...` 调用失败。
**修法**：升级到 ≥ commit `8766a93`（已用 `run_with_timeout` 内置 bash fallback）。

### 症状：内置 Reviewer Codex 报 `env: codex: No such file or directory`

**根因**：`env -i PATH="/usr/local/bin:/usr/bin:/bin"` 抹掉了 `/opt/homebrew/bin`（Homebrew Apple Silicon 默认装位置）。
**修法**：升级到 ≥ commit `8766a93`（已用 `codex_safe_path()` 自动包含 codex binary 所在目录）。

### 症状：YAML 详细 schema `extra_reviewers: [- name: X, checks: [a, b]]` 被错读成多个 reviewer

**根因**：旧版 `parse_extra_reviewers` 用 `^[[:space:]]*-` 贪婪匹配，把嵌套的 check 项当 reviewer 名。
**修法**：升级到 ≥ commit `8766a93`（已改成 YAML indent-aware 解析）。

### 症状：TMUX-YOLO 模式下 milestone / mini-review 从不触发

**根因**：旧版 watcher 不扫 tmux buffer 里的 `# PHASE-N-DONE @` marker，只检测 STATUS.md `^MILESTONE:` 行（Codex 不会自己写）。
**修法**：升级到 ≥ commit `8766a93`（已加 `poll_phase_markers` 每 5s 扫 tmux + 翻译成 STATUS.md MILESTONE 行）。

### 症状：baseline reviewer 跑完但 BASELINE.md 不存在

**根因**：codex 默认 read-only sandbox，写文件被拦。
**修法**：baseline 调用必须带 `--dangerously-bypass-approvals-and-sandbox`（commit `8766a93` 之后默认要求）。

### 症状：文档说 "Review 连续 2 次 fail" 和 "Review 连续 3 轮 fail" 不一致

**根因**：旧版文档自相矛盾。
**修法**：commit `8766a93` 之后统一为 **3 轮**（SKILL.md + stop-conditions.md + watcher.sh 实现一致）。

---

## 关联 skill

- **上游**：用户直接触发 / `flow-dev-task` Stage 5 切换（带 handoff-payload）
- **下游**：`clean-commit`（Step 3.3）/ chrome MCP / `playwright` / `agent-browser`（截图）/ cc-connect（IM）
- **不下游**：`superpowers:test-driven-development`（Codex 内部按 EVAL.md 走）/ `superpowers:verification-before-completion`（已被本 skill 的 baseline + milestone + final review pipeline 替换）
- **Extra Reviewer**：`director-design` / `director-frontend` / `director-promote` / `director-ops` / `director-architect`（按 `role-router.md` 自动建议，用户可在 Phase 0 增删）

---

## 版本 & 维护

- 中心源：[github.com/YeomanYe/skills](https://github.com/YeomanYe/skills) `flow-codex-goal/`
- 实战教训：每次真实长跑跑完后更新 SKILL.md "Red Flags / Rationalizations" 段 + watcher.sh 兼容性 patch
- 兼容平台：macOS（默认无 GNU timeout / coreutils）/ Linux（GNU 默认齐）
