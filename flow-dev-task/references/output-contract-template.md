# flow-dev-task Output Contract — markdown 报告模板

> 本文件是 flow-dev-task 的 **人类可读** Flow Dev Task Report 模板。
> 基线 JSON schema 见 `references/output-contract-schema.md`。
> SKILL.md 主体仅保留对本模板的引用 + 自定义字段说明。

## 落盘约定

- 完整 markdown 报告 subagent **落盘**到 `.agent/jobs/flow-dev-task-<slug>/output.md`
- JSON 返回时 `artifact_path` 字段指向落盘位置
- 主流程展示给用户时再 `Read artifact_path`

## Flow Dev Task Report 模板

```md
## Flow Dev Task Report

### 目标
- 任务类型: feature | bugfix
- 一句话目标:
- 改动范围: <文件数> 文件 / <模块>

### 执行路径
- Brainstorm: done | skipped (reason)
- Writing Plan: done | skipped (reason)
- Worktree: used | not used
- Execute Mode: parallel | subagent | direct | executing-plans
- Executor: Claude self | Codex (rounds: <n>) | Codex→Claude rescue (Codex 失败次数: <n>)
- Codex SPEC compliance: full | partial | broken | n/a
- Codex failure mode: n/a | quota_exhausted | auth_expired | network_transient | hung_timeout | format_error | unknown | spec_partial_after_3_rounds
- TDD: done | skipped (reason ∈ whitelist)

### 交付
- verification-before-completion: pass | fail + reason
- delivery-gate: pass | fail + must-fix list
- microscope: done | skipped (reason: feature 链默认跳 / --auto-recap=false / generation failed) | n/a
- microscope audience: end-user | pm | dev | n/a
- microscope im_pushed: pushed | skipped (no CC_SESSION_KEY) | failed | n/a
- Commit SHA:
- Push status: pushed | skipped | failed | n/a
- Branch handling: merged | PR | cleanup | no-op

### 技术债 / 风险
- <项>: <说明>

### 结论
- 可交付: yes | no
- 剩余问题:
```

## 自定义字段对应

flow-dev-task 在通用 schema 基础上**必填**的扩展字段（机器读 JSON）：

| 字段 | 说明 |
|---|---|
| `task_type` | `feature` / `bugfix` / `merge-resolve` / `accept-review-feedback` |
| `executor` | `claude-self` / `codex` / `codex-then-claude-rescue` |
| `codex_rounds` | 整数；未派 Codex 时 0 |
| `codex_spec_compliance` | `full` / `partial` / `broken` / `n/a` |
| `codex_failure_mode` | 见模板枚举 |
| `tdd_done` | bool；skipped 时 `tdd_skip_reason` 必填 |
| `verification_passed` | bool |
| `delivery_gate_verdict` | `pass` / `must-fix` |
| `change_recap_status` | `done` / `skipped` / `failed` / `n/a` |
| `commit_sha` | string |
| `push_status` | `pushed` / `skipped` / `failed` / `n/a` |
