# Parallelization Template（flow-* skill 共享）

所有 flow-* 编排 skill 共用的并行编排规范。目的：让 orchestrator agent 保持 idle，只做管理（任务分解 / 派工 / 验收 / 仲裁），把执行交给子 agent 并行——避免上下文污染 + 提升吞吐。

---

## 核心原则

1. **orchestrator 只做管理，不做执行**：判断 / Plan / 路由 / 仲裁 / 用户确认 → 自己做；写代码 / 跑命令 / 跑测试 / 截图 → 派 subagent
2. **subagent 默认不会主动用 skill**：prompt 里**必须显式写明"调用 X skill"**（见下方"显式 Skill 指挥"段，这是硬规则）
3. **按 ROI 决定并行**：< 30 行 / < 30 秒 / 高风险代码 / 共享状态 → 不派、不并行
4. **结构化结果回流**：subagent 必须返回 schema 化的结果（slot / status / outputs / errors），orchestrator 只读结论不读过程
5. **共享状态写 race 必须用 reduce 模式**：多 subagent 不直接 append 同一文件；每路写独立 patch，orchestrator 顺序 apply

---

## 显式 Skill 指挥（**硬规则**）

subagent 不会自动触发 skill。orchestrator 派工 prompt 里**必须明确**：

- ✅ "调用 `<skill-name>` skill 完成 X"
- ✅ "用 `superpowers:writing-plans` 写 plan 后再开始"
- ✅ "完成后用 `clean-commit` 提交（如果需要）"
- ❌ "请帮我做 X"（subagent 不会自动用 skill，会用裸 Bash / 直觉解决）

派工模板里如果指定了 skill 调用顺序，subagent 必须严格按顺序触发，不允许跳过 / 替换。

理由：subagent 启动时只读到 prompt，不读 orchestrator 的对话历史。如果 prompt 里没说"用 X skill"，subagent 默认按自己的训练 prior 行事，可能：
- 跳过 TDD（直接写代码不写测试）
- 跳过 brainstorming（直接 implement）
- 跳过 clean-commit（用 `git add .` 粗暴提交）
- 跳过 delivery-gate（直接 commit 不复查）

---

## Subagent 启动模板（三种方式）

### 方式 A：Claude Code Agent 工具（推荐用于并行批处理）

```python
# 多个独立任务 → 一个 message 里多个 Agent 调用 = 真并行
Agent(subagent_type="general-purpose", description="job-1 X",
      prompt="<完整 SPEC，含『必须调用 X skill』>")
Agent(subagent_type="general-purpose", description="job-2 Y",
      prompt="<完整 SPEC，含『必须调用 Y skill』>")
```

特点：天然并行；结果作为 tool result 同时回流；orchestrator 上下文不被子任务过程污染。

### 方式 B：Bash 后台 + watcher

```bash
# 仅适合长耗时（≥ 分钟级）后台任务
nohup bash subjob-1.sh > .agent/jobs/job-1.log 2>&1 &
echo $! > .agent/jobs/job-1.pid
nohup bash subjob-2.sh > .agent/jobs/job-2.log 2>&1 &
echo $! > .agent/jobs/job-2.pid
# orchestrator 自己 idle，由 watcher 监督完成
```

特点：参考 `flow-codex-goal` 的 watcher 模型；适合长跑 + 需要边界守卫的场景。

### 方式 C：Codex `codex exec` 子进程

```bash
codex exec --cd "$WORKTREE" < references/codex-spec-XXX.md
```

特点：参考 `flow-dev-task` Stage 5 + `flow-codex-goal` Reviewer。按 Codex Delegation Hook 的 ROI 阈值决定派不派。

---

## Handoff Payload Schema（扩展 `_shared/handoff-payload-template.md`）

派 subagent 时的 prompt **结构化字段**：

```yaml
# 必填
job_id: "job-N"                    # 唯一标识
parent_orchestrator: "flow-X"       # 上游 orchestrator
slot: "design-sync"                 # 槽位名（reduce 时识别）
inputs:
  - path: "...", sha256: "..."     # 依赖文件 + hash（防中途被改）
expected_outputs:
  - path: ".agent/jobs/N/<file>"   # 必须独立路径，不与其他 job 冲突
  - verification: "test -f ..."     # 验收命令

# 显式 skill 调用顺序（硬规则）
required_skills:
  - "<skill-1>"                     # 必须先调
  - "<skill-2>"
  - "<skill-3>"

# 推荐
time_budget_minutes: 5
risk_class: low | medium | high
forbidden_files:                    # 黑名单
  - "src/api/auth/**"
voice_constraints: "..."            # 如 finish "保留原作者 voice"
```

orchestrator 在派工前必须组装完整 payload，subagent 按此完成后**返回**：

```json
{
  "job_id": "job-N",
  "slot": "design-sync",
  "status": "ok" | "fail" | "partial",
  "outputs": [{"path": "...", "sha256": "...", "lines": 234}],
  "skills_invoked": ["skill-1", "skill-2"],
  "errors": [],
  "duration_seconds": 87,
  "notes": "..."
}
```

---

## 错误恢复策略（按场景选）

### Fail-fast（一路失败立刻停所有）
适用：
- 多路结果有强依赖（一路失败下游全无意义）
- 用户明确说"快速失败"

实现：用 `Promise.race`-like 语义；一路 `status=fail` 立刻 kill 其他 subagent。

### Collect-all（默认）
适用：
- 多路独立（一路失败不影响其他）
- 收集所有错误后由 orchestrator 统一决定

实现：等所有 subagent 完成后汇总；orchestrator 看 `errors[]` 决定哪些重派 / 哪些直接 commit 已完成的部分。

### Retry-individual（少量重试）
适用：
- 临时网络失败 / quota 撞墙
- subagent 失败原因明确可恢复

实现：单 job 重试 ≤ 1 次；连续 2 次失败 → 退回 orchestrator 自己写或 stop。

---

## Reduce 策略（防止 merge 冲突 / race）

**禁止**：多 subagent 同时 append 同一文件（如 README.md / docs/design.md）。

**正确模式**：

### 方式 1：独立 patch 文件 + orchestrator 顺序 apply

```bash
# 每个 subagent 写到独立路径
.agent/jobs/job-1/output.patch
.agent/jobs/job-2/output.patch
.agent/jobs/job-3/output.patch

# orchestrator 收集 + 按 slot 顺序合并
for slot in design-sync interaction-sync prd-sync architecture-sync; do
  patch -p1 < .agent/jobs/$slot/output.patch
done
```

### 方式 2：独立目录写完整文件 + orchestrator 拷贝/重命名

```bash
.agent/jobs/job-1/docs/design.md     # 完整文件
.agent/jobs/job-2/docs/interaction.md
# orchestrator 直接 cp 到目标位置
```

### 方式 3：内存级 JSON 汇总

```python
# subagent 返回 JSON 给 orchestrator
results = [job1_result, job2_result, ...]
# orchestrator 拼装最终文件
final_doc = render_template(results)
```

**选择**：写大文档 → 方式 1 / 写新文件 → 方式 2 / 数据型结果 → 方式 3

---

## 并行 ROI 阈值

派 subagent 并行之前必须过 4 道闸：

| 检查 | 阈值 | 不过则 |
|---|---|---|
| 子任务规模 | ≥ 30 行 / ≥ 2 文件 | 不派，orchestrator 自己写 |
| 子任务耗时 | ≥ 30 秒 | 不并行（启动开销 > 节省）|
| 子任务数量 | ≥ 2 个独立任务 | 1 个就别并行 |
| 共享状态 | 同一文件 / 同一浏览器 session / 同一 git index | 不并行（race） |
| 风险等级 | auth / 支付 / 加密 → orchestrator 自写 | 不派 |

详细 Codex Delegation Hook 见 `flow-dev-task` 的同名段。

---

## 引用方式（各 flow-* 在 SKILL.md 加段）

```md
## Parallelization Plan

并行编排规范遵循 `_shared/parallelization-template.md`。

### 本 skill 的并行集合

- **集合 1（并行）**：[Step X, Step Y, Step Z] — 独立写不同文件，可同时跑
  - subagent 启动方式：方式 A（Agent 工具批处理）
  - reduce 策略：方式 2（独立目录写完整文件）
  - skill 必须调用：`<skill-1>` `<skill-2>`
- **集合 2（串行）**：Step A → 集合 1 → Step B
- **不并行**：Step C（高风险 / 共享状态）

### orchestrator 在派工期间 idle

派 subagent 后 orchestrator 进入 idle，仅在以下时刻被唤醒：
1. 所有 subagent 返回结果
2. 人类主动 ping
3. fail-fast / stop signal 触发
```

---

## Reference Design

`flow-codex-goal` v3 是 orchestrator idle + 多独立进程编排的**完整范本**：
- orchestrator 只做 4 类决策（契约 / ping / 仲裁 / stop）
- watcher.sh 接管自动化（health-check / boundary / inbox-poll / milestone / review）
- Goal Codex / Reviewer Codex / mini-review Codex 三种独立进程
- review-audit/round-N.jsonl 结构化结果
- snapshot + 最高分回退

其他 flow-* 改造时优先参考此设计，但**不必每个都启 daemon watcher**——轻量场景用方式 A（Agent 工具批处理）即可。
