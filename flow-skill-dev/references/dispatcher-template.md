# Dispatcher Template — 派 subagent 调下游 skill 的 prompt 通用模板

> 所有 orchestrator / dispatcher 类 skill(flow-* / director-* / todo-flow / exp-sum / microscope)
> 派 subagent 时,prompt **字段集 + 行为约束**统一遵循本模板。各 skill 自身只写"差异部分"。

## 用途

本模板回答**一个**问题:**派 subagent 调下游 skill 时,prompt 怎么写、subagent 怎么受约束?**

跟两个相邻共享文件的边界:

| 文件 | 管什么 | 不管什么 |
|---|---|---|
| `parallelization-template.md` | **什么时候**派、并几路、reduce 怎么合 | prompt 字段长什么样 |
| `handoff-payload-template.md` | orchestrator **之间**交接的 payload schema | 单次 dispatch 的 prompt 模板 |
| **`dispatcher-template.md`(本文件)** | 单次 dispatch 的 **prompt 字段清单 + subagent 行为约束** | 并行决策 / 跨 orchestrator handoff |

**不要在本文件重复**并行 ROI 阈值、reduce 模式、handoff payload 全字段表——直接引用上述两文件。

## 模板字段清单

派工 prompt 必须含以下字段。**必填**意味着缺了 subagent 会跑歪。

### 1. Task(必填,1 行)

一句话目标,不超过 80 字。**不写实现细节**,实现交给 skill 自己。

✅ `Task: 对当前 PR diff 做 director-design audit,出 verdict + must-fix`
❌ `Task: 请你用 playwright 打开 localhost:5173 然后截图...(50 行细节)`

### 2. Skill invocation directive(必填,**硬规则**)

prompt 必须显式写:

```
必须调用的 skill:
  - **<skill-name>**(mode=<mode> 如果有)
    subagent 默认不会主动 use skill,本指令明确要求你 invoke <skill-name>
    不要复述 SKILL.md 内容,直接 invoke 让 skill 加载
```

**理由**:subagent 启动时只看 prompt + 自己的训练 prior,**不会主动触发 skill**。不显式写 = subagent 按裸 LLM 直觉跑,会跳过 TDD / clean-commit / delivery-gate / Output Contract,产出质量塌方。

详见 `parallelization-template.md` 的"显式 Skill 指挥"段(硬规则)。

### 3. Handoff payload(必填,**path-based 优先**)

字段集遵循 `handoff-payload-template.md`。**关键规则:大块内容传路径不传内联**。

| ❌ 错(内联) | ✅ 对(path-based) |
|---|---|
| `spec: "<200 行 spec 全文>"` | `spec_path: ".agent/specs/<slug>.md"` |
| `diff: "<diff 全文>"` | `diff_path: ".agent/jobs/<job>/diffs.patch"` |
| `screenshots: [<base64...>, ...]` | `evidence_paths: [".agent/jobs/<job>/shot-1.png"]` |
| `prior_context: "<5000 字会话历史>"` | `prior_context_path: ".agent/jobs/<job>/context.md"` |

**为什么**:subagent prompt 本身要消耗主上下文 token(prompt 走 Agent 工具时计入主会话的 tool_input)。内联大内容 = 同一份内容在主上下文与 subagent 上下文里各放一份 = 主上下文双倍污染。Path-based 让 subagent 自己 `Read`,主上下文只见一行路径。

最小字段集(必填):

```yaml
task_id: <date>-<slug>
objective: <一句话>
risk_class: low | medium | high
evidence_paths: [<path>, ...]      # 可空 list,不可缺 key
spec_path: <path 或 null>
prior_context: <object 或 null>
```

完整字段定义见 `handoff-payload-template.md`。

### 4. Input scope(必填)

明示 subagent 可碰 / 不可碰的范围:

```
Input scope:
  read_only: [<paths>]              # 显式列出可读路径
  write_to: .agent/jobs/<job-slug>/ # 默认输出目录,subagent 只能写这里
  forbidden: [<paths>]              # 显式黑名单(如 src/api/auth/**)
  no_git_ops: true                  # 默认禁 commit / push / branch / reset
```

理由:subagent 默认按 LLM 直觉乱碰文件(看到啥改啥)。不限定 scope = race / 误改 / 撞主分支。

### 5. Output contract(必填)

引用 `_shared/output-contract-schema.md` 基线 JSON + 该次 dispatch 的扩展字段。
(注:`output-contract-schema.md` 还未建,主流程会建——本文件先按约定写。)

要求 subagent:
- **完成时返回 JSON 到 stdout**(主上下文只读 JSON,不读 markdown)
- **完整 markdown 报告写到 `artifact_path`**(默认 `.agent/jobs/<job>/output.md`)

最小 JSON schema:

```json
{
  "verdict": "pass | pass-with-fixes | needs-revision | failed",
  "aggregate": 0.0,
  "must_fix": [],
  "errors": [],
  "artifact_path": ".agent/jobs/<job-slug>/output.md",
  "duration_seconds": 0
}
```

各 skill 可在此基线上加扩展字段(如 director-design 加 `aesthetic_score`,
director-frontend 加 `boundaries_clean`)。

### 6. Constraints(推荐)

```
Constraints:
  failure_mode: failed_stop | failed_continue_main | retry_n_times(n=1)
  timeout_mins: <n | 0=unlimited>
  heartbeat_file: <path 或 null>   # 长跑任务必填,见 todo-flow exec 模式
  max_parallel: <n>                # 若派多路,显式声明并行度
```

#### failure_mode 三档语义

| 值 | 语义 | 何时用 |
|---|---|---|
| `failed_stop` | 任一路失败立刻终止全部 + 整体回退 | 多路结果强依赖 |
| `failed_continue_main` | 失败路返回 error,主流程继续(可能降级) | 多路独立,允许部分失败 |
| `retry_n_times` | 单路失败重试 ≤ n 次,仍失败转 stop | 临时网络/quota 失败可恢复 |

#### timeout / heartbeat

- 短任务(< 5 分钟):`timeout_mins=5`,不需要 heartbeat
- 中长(5-30 分钟):`timeout_mins=30` + `heartbeat_file`(subagent 每 N 秒 touch)
- 无人值守长跑:`timeout_mins=0` + `heartbeat_file` + 外部 watcher(参考 flow-codex-goal)

## 完整模板(可 copy 直接用)

```
Task: <一句话目标>

必须调用的 skill:
  - **<skill-name>**(mode=<mode>)
    subagent 默认不会主动 use skill,本指令明确要求你 invoke <skill-name>

Handoff payload(path-based):
  task_id: <date>-<slug>
  objective: <text>
  risk_class: low | medium | high
  evidence_paths: [<path1>, <path2>, ...]
  spec_path: <path 或 null>
  prior_context: { ... 或 null }

Input scope:
  read_only: [<paths>]
  write_to: .agent/jobs/<job-slug>/
  forbidden: [<paths>]
  no_git_ops: true

Output contract:
  返回 JSON to stdout(基线见 _shared/output-contract-schema.md):
    {
      "verdict": "...",
      "aggregate": 0.0,
      "must_fix": [],
      "errors": [],
      "artifact_path": ".agent/jobs/<job-slug>/output.md",
      "<本次扩展字段>": ...
    }
  完整 markdown 报告写到 artifact_path = .agent/jobs/<job-slug>/output.md

Constraints:
  failure_mode: failed_stop | failed_continue_main | retry_n_times
  timeout_mins: <n | 0>
  heartbeat_file: <path 或 null>
  max_parallel: <n,若派多路>
```

## 各 skill 如何引用本模板

各 dispatcher skill 的 SKILL.md 在派 subagent 段**只需写差异部分**(5-15 行):

```md
## Subagent 派工

派 subagent 时按 `references/dispatcher-template.md` 完整模板填字段。

本 skill 特定:
- 必须调用的下游 skill: `<X>`(mode=`<Y>`)
- 必填扩展字段:
  - `<field-1>`: <说明>
  - `<field-2>`: <说明>
- 失败处理: `<failure_mode>`
- 超时: `<n>` 分钟 / `heartbeat_file=<path>`(长跑时)
- 并行度: `<n>` 路(若批派)
```

原本 50-100 行模板压缩到 5-15 行,共性部分集中在本文件维护。

## 反例 — 别这么写派工

| 反例 | 问题 | 改法 |
|---|---|---|
| prompt 里粘贴 spec / diff / 截图 base64 全文 | 污染主上下文 token | path-based,只传路径 |
| `"请帮我做 X"`(不写 invoke skill) | subagent 不会主动 use skill,按裸 LLM 直觉跑 | 显式 directive: `必须调用的 skill: <X>` |
| `"返回 markdown 报告"`(stdout 全 md) | 主上下文被 md 报告污染 | JSON to stdout + 完整报告写 `artifact_path` |
| 模糊的失败处理(`"失败就处理一下"`) | 卡死或乱重试 | 显式 `failure_mode: failed_stop \| ... \| retry_n` |
| 不限定 scope | subagent 乱碰文件 / 撞主分支 / 误 commit | 明示 `read_only` + `write_to` + `no_git_ops` |
| 派长跑无 heartbeat | orchestrator 不知道死活,要么死等要么误杀 | `heartbeat_file=<path>` + watcher |
| 派多路不声明 `max_parallel` | 资源竞争 / quota 撞墙 | 显式 `max_parallel: <n>` |
| 把 `${task_id}` / `<placeholder>` 留在 prompt 里 | subagent 读到字面占位符直接 idle | dispatcher 必须**字面替换**所有占位符再派 |

## 与其他共享文件的协作

派一次工的完整决策链:

```
1. 决定派不派 / 并几路(并行 ROI)
   → 参考 parallelization-template.md
2. 决定传什么 handoff payload(跨 orchestrator 交接的字段)
   → 参考 handoff-payload-template.md
3. 决定派工 prompt 怎么写(字段 + 约束)
   → 参考本文件 dispatcher-template.md
4. 决定 subagent 返回什么(JSON schema)
   → 参考 output-contract-schema.md(主流程会建)
5. 多路结果怎么 reduce
   → 回到 parallelization-template.md 的"Reduce 策略"段
```

## 已使用本模板的 skill(预期同步目标)

`_scripts/sync-shared.sh` 需把本文件同步到以下所有 orchestrator / dispatcher 类 skill 的
`references/dispatcher-template.md`:

- **flow-* 编排器**:flow-codex-goal / flow-dev-task / flow-project-finish /
  flow-project-bootstrap / flow-ext-publish / flow-skill-dev / flow-skill-research
- **todo-flow**(exec 模式重度派工)
- **director-* 角色**:director-design / director-frontend / director-promote /
  director-ops / director-architect(5 个全员)
- **辅助 orchestrator**:exp-sum / microscope

各 SKILL.md 引用路径用 `references/dispatcher-template.md`(同级相对),不要写
`_shared/dispatcher-template.md`(skillshare 同步后 `_shared/` 不在目标环境)。
