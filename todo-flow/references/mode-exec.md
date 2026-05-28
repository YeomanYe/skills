# Mode `exec` — 前台 orchestrator 自闭环跑 stage1→2→3

**前台自闭环 orchestrator**:对一个或多个项目的若干 spec 自动驱动 stage1→stage2→stage3 直到每个 slug 进入终态(`verified` 或 `blocked`),不需人审介入。

跟 cron 模式(state-model.md 调用拓扑里的 stage1/2/3)的区别:

- **cron**: 慢节奏后台,每个 stage 独立 cron,一轮只处理 1 个 spec,适合"放着自己跑"
- **exec**: 前台 orchestrator 进程,**并发** + **per-slug 紧逼到 verified/blocked**,适合"今晚把这批 TODO 推完"

> 完整 prompt 在 `references/exec-orchestrator-prompt.md`(642 行),本文件只列入口流程 + 关键设计 + 硬护栏。

## Required Workflow

按以下顺序:

0. 解析 CLI 参数(`--project <p1> [<p2> ...]`、可选 `--slug <s1> [<s2> ...]`、`--max-verify-attempts <n>`(默认 5)、`--poll-interval <sec>`(默认 300)、`--stuck-after <sec>`(默认 900)、`--backend codex|claude`、`--resume`、`--no-im`、`--exclude-needs-rework`)
   - **`--resume` 行为**:跳过 Step 0 队列构建,直接读 `.todo-flow/exec/.session-state.json` 恢复上次中断时的 in-flight + pending queue。续跑过程中按需 re-check 各 spec 当前 status(允许用户在中断期手工改 spec)。续跑成功完成后删除 `.session-state.json`。文件不存在 → idle 退出 + 提示"无可续跑 session"
1. 校验环境:`cc-connect` 可用(除非 `--no-im`)+ subagent backend 可用 + 各 project 是 git 仓库
2. 读 `references/exec-orchestrator-prompt.md` 整篇,**字面替换**以下占位符:
   - `${PROJECTS_ARRAY}` → JSON 数组 `[{name, abs_path, default_branch}, ...]`
   - `${SLUGS_FILTER}` → 用户指定的 slug 数组(可空)
   - `${MAX_VERIFY_ATTEMPTS}` → 默认 5
   - `${POLL_INTERVAL_SEC}` → 默认 300
   - `${STUCK_AFTER_SEC}` → 默认 900
   - `${SUBAGENT_BACKEND}` → `codex` 或 `claude`
   - `${IM_ENABLED}` → `true` 或 `false`
3. **以替换后的 prompt 作为 agent 自身的工作指令**继续执行(主 agent 本身就是 orchestrator)。**不要再派一层 subagent 当 orchestrator**——orchestrator 由当前 agent 直接扮演,这是为了让用户能 Ctrl+C 中断 + 看实时进度
4. 主循环跑到队列空 / 死锁 / 用户中断
5. 输出标准 JSON(详见 exec-orchestrator-prompt.md "输出契约"段)

## 关键设计原则

- **per-stage subagent**:不派一个 subagent 跑完整 slug,而是每次只派一个 subagent 跑一个 stage。stage 返回后 orchestrator 看 spec status 决定下派什么 stage。这样故障粒度最小、状态机最干净
- **stage1 只跑 1 次**:spec 一旦生成视为给定,exec 模式不允许循环重做 stage1(spec 本身怀疑错 → blocked 求人)
- **强制 auto-approved**:exec 不看 stage1 self_approved,所有 spec 直接进 stage2
- **stage3 verify-failed 自动生成 `## Rework instructions`** 写到 spec 头部,stage2 下轮必读。**不调** `revise` 模式
- **director-* AND-pass**:stage3 Playwright 通过后,按 spec frontmatter `director_audit` + `required_directors` 增派 director-* 并行 audit,**全 pass** 才标 verified
- **IM 同步阻塞**:cc-connect send 失败 = orchestrator 停下来报警,不重试不静默丢弃
- **不自动 done**:exec 跑完 verified 后停止,用户手工 `todo-flow done` 完成 merge

## 硬护栏(5 种 blocked 触发,与 state-model.md "Exec 模式 blocked 触发"段完全对齐)

| 触发 | 谁标记 | 说明 |
|---|---|---|
| `attempts >= 3`(stage2 内部 IMPL_FAIL 累积) | stage2 prompt 自己标 | 保留现有 cron 模式逻辑,exec 不绕开 |
| `verify_attempts >= --max-verify-attempts`(默认 5) | exec orchestrator 标 | exec 专属硬上限 |
| 连续 3 次 stage3 failure signature hash 相同(归一化后) | exec orchestrator 标 | 防"换汤不换药"循环 |
| `relaunch_count >= 3`(心跳 L3:重派 3 次仍 L2 卡死) | exec orchestrator 标 | 心跳 L1 唤醒 → L2 kill+重派 → 第 3 次重派后仍 L2 → L3 blocked |
| 循环依赖检测(spec depends_on 形成环) | exec orchestrator 标 | 涉及所有环上 slug 一起 blocked + IM 告知 |

blocked 标完 → IM 通知用户 + 该 slug 移出队列 + 保留 `.todo-flow/exec/<slug>/` 不清理(供人 review)。

## 与其他 mode 的关系

- `add` / `adjust`:可在 exec 跑期间运行,但 adjust **应避免**(状态机可能不一致)
- `revise`:exec 不会自动调;`revise` 后改 spec 为 needs-rework,**下一次** `todo-flow exec --resume` 才会被纳入(needs-rework 在 exec Step 0 默认过滤;`--include-needs-rework` 可纳入)
- `done`:exec 跑完 verified 后 **必须** 用户手工 done(squash merge + 版本升级 + CHANGELOG)

## Output Contract

详见 `references/exec-orchestrator-prompt.md` "输出契约" 段。核心字段:

```json
{
  "mode": "exec",
  "verdict": "completed | interrupted | deadlock | skipped",
  "total": <n>, "verified": <n>, "blocked": <n>, "interrupted": <n>,
  "per_slug": [{project, slug, final_status, stages_run, directors, duration_sec, evidence_dir}],
  "duration_sec": <n>,
  "summary": "exec <n> verified, <n> blocked across <n> projects",
  "next_action": "blocked 项需人 review:todo-flow revise 给新指令,或人工修后 todo-flow done"
}
```

## Common Failure Modes

**1. 不读 exec-orchestrator-prompt.md 直接凭脑补跑**:模式定义在 reference 里,SKILL.md 只列 mode 入口。Step 2 必读全文 + 字面替换占位符,**不要** 把占位符当字符串保留。

**2. subagent 自己发 IM 而不通过 orchestrator**:IM 出口必须单一,subagent prompt 里要明确禁止;若发现重复 IM,检查 stage prompt 是否被污染。

**3. cc-connect send 失败后继续派 stage**:IM 是关键反馈通道,失败必须停;后续 IM 漏发等于盲跑。

**4. director-* audit pass 但有 must_fix 被忽略**:AND-pass 的 pass 必须 must_fix 为空;非空一律按 needs-fix 走 verify-failed 路径。

**5. exec 跑完顺手帮用户调 `todo-flow done`**:严禁。done 是高风险动作,保留人审最后关口。

**6. 在 exec 期间用户改了 spec**:每轮 orchestrator 重读 spec status,以最新为准;若变 verified/blocked → 从队列移除。

**7. backend=claude 主会话退出后 subagent 也死**:Claude Code Agent 后台是同会话内有效,**用户要真后台 exec 应用 `--backend codex`**;SKILL 解析 mode 时检测主 agent 是 Claude Code 且未显式 `--backend codex`,提示用户改 backend。
