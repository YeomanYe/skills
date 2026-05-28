# Codex Delegation Hook — 详细派工流程

> 本文件展开 `SKILL.md` 中 Codex Delegation Hook 的完整流程：错误分类表、5 步派工、退回处理。
> SKILL.md 主体仅保留判定信号和关键决策；细节查这里。

## 前提认知

**Codex 是对等 agent（不是工具）**：具备本机所有工具（bash / 文件 / 浏览器自动化 / skills），能做 Claude 能做的所有事。

**派工不是"能不能"，是 ROI**：

> 净收益 = 省 Claude token + 并行性 - SPEC 撰写成本 - 协调成本 - review 成本 - 质量风险

进入 Stage 5 前按以下顺序判定**执行者**。Codex 是"执行替代"，**不替代** TDD / verification / delivery-gate / commit。

## 判定信号

### 必须 Claude 自写（任一命中 → 不派 Codex）

1. 用户明说"自己写 / 别派 Codex / 你来"
2. 改动预估 < 30 行 **或** < 2 文件
3. 高风险代码：auth / 支付 / 加密 / 输入校验 / 数据访问层 / 安全敏感
4. 任务紧密依赖会话上下文（前几轮推断的状态、未落地的设计）
5. Codex 不可用：`which codex` 无返回 / 登录失败 / 网络异常
6. bugfix 链下，根因尚未在 systematic-debugging 中确认

### 默认派 Codex（不命中上面 + 任一命中下面）

1. 改动 ≥ 30 行 **或** ≥ 2 文件
2. 任务可独立 SPEC 化（不需会话上下文也能写完整 SPEC）
3. 任务以样板为主：CRUD / UI scaffolding / 测试用例生成 / 配置文件 / 格式转换 / 重命名

## Codex 派工 5 步

**Step 0（前置）**：进入 Stage 5 第一件事执行 `which codex && codex --version`。
任一失败 → 命中"Codex 不可用"，整个 Stage 5 走 Claude 自写。

**Step 0.5（运行时探测）**：binary 存在不等于可用。每次 `codex exec` 后必须按 Codex 运行时错误分类（见下表）判定失败类型，**永久性错误立即退回 Claude，不消耗返工次数**。

1. **Claude 写 SPEC**：使用 `references/codex-spec-template.md` 模板，必须含：
   - 目标 / 范围（涉及/不涉及文件）/ 输入输出 / 技术约束
   - 验收 hard gates（功能、类型、lint、测试可验证项）
   - 不在 TDD Whitelist → SPEC **强制 RED→GREEN 顺序**（先 commit failing test，再 commit 实现）
   - 报告要求 JSON schema（含 `tests_written_first` / `spec_compliance` 等字段）
2. **派工**：使用 `references/codex-delegation-prompt.md` 模板拼 prompt
   - `codex exec --skip-git-repo-check <prompt>` 或 `/codex`（codex-plugin-cc 已装时）
   - prompt 必须包含：让 Codex 先读项目根 `AGENTS.md`、SPEC 全文、报告 schema、"Critical" 防谎报段
3. **Codex 输出 JSON 报告**
4. **Claude review**（不可省略，逐项核对）：
   - 跑 SPEC 中所有 hard gate 命令（typecheck / lint / test），用**真实输出**对照 Codex 报告
   - hard gates 全过：
     - [ ] `spec_compliance == "full"`（或 deviations 全部合理）
     - [ ] `tests_passed == true` 且 Claude 自跑也 pass
     - [ ] `tests_written_first == true` 且 `git log --oneline` 显示 failing test commit 在 impl commit 之前（TDD 路径）
     - [ ] `git diff --stat` 显示**只动了 SPEC「范围」文件**
     - [ ] 没引入未授权新依赖（`git diff package.json`）
     - [ ] 没 TODO / FIXME / `mock` 关键词残留（除非 SPEC 允许）
5. **判定**（必须先按 Codex 运行时错误分类，再决定下一步）

## Codex 运行时错误分类表

| 症状 | 类型 | 动作 | 是否计入 3 次 |
|---|---|---|---|
| Exit 0 + 有效 JSON + `spec_compliance: "full"` | 成功 | → Stage 6 | n/a |
| Exit 0 + 有效 JSON + `spec_compliance: partial \| broken` | 可修 | 用返工 prompt 送回 Codex | 是 |
| Exit 0 但**无 JSON** 或 JSON 字段缺失 | 格式错误 | 返工时明示"必须输出标准 JSON 块" | 是 |
| stderr 含 `rate limit` / `quota` / `credit` / `402` / `usage limit` | **额度耗尽** | **立即退回 Claude**；提醒用户检查订阅/账单 | **否** |
| stderr 含 `unauthorized` / `401` / `login expired` / `not authenticated` | **认证失效** | **立即退回 Claude**；提醒用户跑 `codex login` | **否** |
| stderr 含 `network` / `timeout` / `ECONNREFUSED` / `ENETUNREACH` / `ENOTFOUND` | **瞬时网络** | 重试 1 次；仍失败 → 退回 Claude | 否（重试 1 次不计入）|
| 命令超过 10 分钟无返回 | **挂起** | `kill` Codex 进程 → 退回 Claude | **否** |
| 其他未知错误 | 未知 | 返工 1 次试探；仍失败 → 退回 | 是 |

## 退回 Claude 时的统一处理

- 永久性错误（额度/认证/挂起）：Output Contract 的「技术债」记录 `Codex unavailable: <error type> — <suggested user action>`
- 可修错误 3 次返工失败：把 3 次报告作为参考输入给 Claude，避免重头再来
- 任何退回都要在用户回复中**明确告知失败原因**，不能默默退回

## Codex 派工时仍要遵守的原则

- **TDD**：SPEC 强制 RED→GREEN，Codex 必须先写 failing test。**Codex 路径下不调用 `superpowers:test-driven-development` skill**，TDD 方法通过 SPEC + git commit 顺序检查强制
- **verification**：Stage 6 由 **Claude 亲跑**，不信 Codex 自报 `tests_passed`
- **delivery-gate**：Stage 7 不可跳
- **commit**：Stage 8 由 Claude 完成。**Stage 8 调 clean-commit 时必须显式传入 Codex 信息**（派工次数、最终 spec_compliance），让 commit message 能反映；commit message 模板示例：`feat(X): implement Y (Codex: 1 round, full SPEC compliance)`
