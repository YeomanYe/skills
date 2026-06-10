# Output Contract Schema — 跨 skill 统一 JSON 字段规范

> 本文件定义所有产出报告类 skill(director-* / flow-* / experience-summary /
> change-recap / hat 等)的 **Output Contract 基线 JSON 字段** + **markdown 报告落盘约定**。
> 当前 16 个 skill 在 SKILL.md 主体内联 30-50 行 markdown 模板的做法已下沉到
> 各 skill 自己的 `references/output-contract-template.md`,主体只保留对本规范的引用 +
> 自定义字段声明。

## 为什么需要

历史上每个 skill 的 `## Output Contract` 段直接内联 30-50 行 markdown 报告模板,
subagent 派工回报必须把完整 markdown 复述到 stdout。两个真实问题:

1. **SKILL.md 主体膨胀**(模板段往往是 SKILL 体量第 2 大段,挤压判断/流程段位置)
2. **subagent → 主上下文回流污染**(完整 markdown 经 stdout 回流压主 context window,
   往往主流程只关心 verdict / must_fix 一两个字段,却被迫吞下全文)

**解法**: 把"机器读"和"人类读"两路分开:
- **机器读**(主流程裁决用): 精简 JSON,固定 schema,只回必要字段
- **人类读**(展示 / handoff 给下游用): 完整 markdown,subagent **落盘**,
  主流程要展示时再 `Read artifact_path`,**lazy load**

## 核心约定

1. subagent 派工**返回 JSON**(基线字段 + skill 扩展字段),**不返回 markdown 全文**
2. 完整 markdown 报告由 subagent **落盘**到 `.agent/jobs/<task-slug>/output.md`
3. JSON 必填 `artifact_path` 字段指向该 markdown 落盘位置
4. 主流程要展示给用户 / 移交下游 skill 时,**按需** `Read artifact_path`
5. subagent 派工 prompt 必须**明示**: "返回 JSON,不要在 stdout 复述 markdown 全文"

## 通用 JSON Schema(基线字段)

```json
{
  "verdict": "<enum>",                       // 必填,具体可选值由各 skill 定义
  "aggregate": 0.0,                          // 可选,审计/打分类 skill 才用(0.0-5.0)
  "must_fix": ["<string>", ...],             // 必填,空数组 [] 也可
  "should_fix": ["<string>", ...],           // 可选
  "evidence_paths": ["<path>", ...],         // 可选,截图 / diff / log 等佐证文件
  "artifact_path": "<path>",                 // 必填,完整 markdown 报告落盘位置
  "errors": ["<string>", ...],               // 可选,执行期错误(非业务 fail)
  "notes": "<string>"                        // 可选,补充说明(尽量短)
}
```

### 字段语义细则

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `verdict` | enum string | 必填 | 各 skill 自定义可选值集合(见 Verdict 映射规范) |
| `aggregate` | number | 可选 | 审计类 skill 输出 0.0-5.0;非审计类不要 |
| `must_fix` | list[string] | 必填 | 阻塞交付的发现;无则传 `[]`,不要省略字段 |
| `should_fix` | list[string] | 可选 | 不阻塞但建议修的发现 |
| `evidence_paths` | list[path] | 可选 | 截图 / diff / log 等绝对路径;给下游交叉核对 |
| `artifact_path` | path | 必填 | `.agent/jobs/<task-slug>/output.md` 完整 markdown 报告 |
| `errors` | list[string] | 可选 | 执行错误(命令失败 / 超时 / 网络断),区别于业务 fail |
| `notes` | string | 可选 | ≤ 200 字补充;长内容请放 artifact_path |

## 各 skill 如何扩展

各 skill 可在基线之上加**自定义字段**,在 SKILL.md 的 `## Output Contract` 段
显式声明(类型 + 含义)。常见扩展:

| Skill | 扩展字段示例 |
|---|---|
| `director-ops`(install/uninstall) | `tool` / `mode` / `version_installed` / `verify_pass` / `knowledge_path` |
| `director-design`(audit/mockup) | `design_tokens_source` / `viewport_covered` / `mockup_path` |
| `director-frontend`(implement/extract) | `files_touched` / `boundaries_extracted` / `handoff_spec_path` |
| `director-architect`(research/land) | `rules_structure_diff` / `affected_domains` / `migration_count` |
| `director-promote`(draft/dispatch) | `platforms` / `variants_count` / `dispatch_receipts` |
| `flow-dev-task` | `executor` / `codex_rounds` / `spec_compliance` / `commit_sha` |
| `flow-codex-goal` | `score_trajectory` / `highest_tag` / `reviewer_pids` |
| `experience-summary` | `routing_target` / `layer_assigned` / `one_liner_summary` |
| `change-recap` | `audience` / `task_type` / `recap_markdown` / `im_pushed` |

各 skill 的 SKILL.md `## Output Contract` 段**新格式**(≤ 15 行):

> 按 `references/output-contract-schema.md` 基线 JSON 字段返回 + 本 skill 扩展字段:
>
> ```json
> {
>   "...基线字段...": ...,
>   "<自定义字段1>": "<类型与含义>",
>   "<自定义字段2>": "..."
> }
> ```
>
> 完整 markdown 报告落盘到 `.agent/jobs/<本 skill 命名规范>/output.md`,
> 模板见本 skill `references/output-contract-template.md`
> (只在主流程需要展示给用户 / 移交下游时读;subagent 不要在 stdout 复述全文)

(原来内联的完整 markdown 模板**整段保留**搬到各 skill `references/output-contract-template.md`)

## artifact_path 命名规范

约定路径格式: `.agent/jobs/<task-slug>/output.md`

- `<task-slug>` 由调用方决定,**必须可追溯到具体任务**,例如:
  - `director-ops` install nodejs → `.agent/jobs/director-ops-install-nodejs/output.md`
  - `director-design` audit popup → `.agent/jobs/director-design-audit-popup-20260528/output.md`
  - `flow-dev-task` batch3 → `.agent/jobs/flow-dev-task-batch3/output.md`
  - `experience-summary` triage → `.agent/jobs/exp-sum-<topic-slug>/output.md`
  - `flow-codex-goal` long-run → `.agent/jobs/flow-codex-goal-<task-id>/output.md`
- `.agent/jobs/` 应已加入 `.gitignore`(若调用方项目无此条目,subagent 应在 notes 提醒)
- 同 task-slug 重跑会**覆盖** output.md(若需历史,自行加日期/序号到 slug)

## 迁移指南(给 16 skill 改造作者用)

各 skill 把现有 `## Output Contract` 段切到本规范的步骤:

1. **主 SKILL.md `## Output Contract` 段**:替换为"引用本规范 + 列扩展字段 +
   引用本 skill `references/output-contract-template.md`"(≤ 15 行)
2. **原内联的完整 markdown 模板**:**整段搬**到 `references/output-contract-template.md`
   (不简化、不删字段,保留 ACBDQC 佐证要求)
3. **派 subagent 时 prompt 明示**:
   > "返回 JSON(按 references/output-contract-schema.md 基线 + 本 skill 扩展字段),
   > 完整 markdown 报告写到 `artifact_path`,**不要在 stdout 复述 markdown 全文**"
4. **主流程 review** 时:按 JSON 字段判定(verdict / must_fix / aggregate);
   需要详细信息或要 handoff 给下游时再 `Read artifact_path`

### 迁移示例(对比)

**旧格式**(SKILL.md 内联 50 行 markdown 模板):

```md
## Output Contract

每次完成必须输出（强制全字段）：

```md
## Director-Ops Report

### 任务理解
- 用户原话:
- mode 判定: install | uninstall
... (后面 45 行)
```
```

**新格式**(SKILL.md ≤ 15 行,只声明 JSON):

```md
## Output Contract

按 `references/output-contract-schema.md` 基线 JSON 字段返回 + 本 skill 扩展字段:

\`\`\`json
{
  "verdict": "installed-clean | installed-with-warnings | partial | failed",
  "aggregate": 4.5,
  "must_fix": [],
  "artifact_path": ".agent/jobs/director-ops-<tool>-<mode>/output.md",
  "tool": "<software-name>",
  "mode": "install | uninstall",
  "version_installed": "<x.y.z | null>",
  "verify_pass": true,
  "knowledge_path": "~/Documents/knowledge/<tool>-{install|uninstall}.md"
}
\`\`\`

完整 markdown 报告模板见 `references/output-contract-template.md`
(主流程要展示给用户时读;subagent 不要在 stdout 复述)
```

## 回归测试(integration test 提示)

各 skill 接入本规范后,integration test 至少覆盖:

1. **JSON 合法性**: subagent 回流的 JSON 能 `JSON.parse` 通过,基线必填字段都在
2. **artifact 真实存在**: `artifact_path` 指向的文件**真的被写入**(非空,含 ≥ 报告骨架)
3. **stdout 不复述全文**: subagent stdout 不含 artifact 内任意 ≥ 80 字符段落
   (抽样比对;若命中 = 违反契约,subagent prompt 写得不够明示)

## 已使用本模板的 skill

下列 skill 必须按本规范出具 Output Contract(共 17 个):

- 5 个 director-*: director-design / director-frontend / director-promote / director-ops / director-architect
- 8 个 flow-*: flow-dev-task / flow-codex-goal / flow-cron / flow-project-finish / flow-project-bootstrap / flow-ext-publish / flow-skill-dev / flow-skill-research
- experience-summary
- change-recap
- hat
- todo-flow

新加产出报告类 skill 时同步加入 `scripts/sync-shared.sh` 的
`output_contract_schema_target_skills` 数组。

## 引用方式

各 skill 在 `## Output Contract` 段第一行:

```md
按 `references/output-contract-schema.md` 基线 JSON 字段返回 + 本 skill 扩展字段:
```

skillshare 同步后,`references/output-contract-schema.md` 仍可达
(由 `scripts/sync-shared.sh` 从 `_shared/` 分发)。
