# Codex 派工 SPEC 模板

派 Codex 前 Claude 必须写一段满足以下结构的 SPEC，可放在 `docs/SPEC-<task>.md` 或直接作为 prompt 的一部分。

## 结构

```markdown
# SPEC: <任务名>

## 目标
<一句话说清要解决什么问题>

## 范围
- 涉及文件：[file1, file2, ...]
- 不涉及（明确排除）：[file3, ...]
- 不允许新建文件（除非列在）：[allowed_new_files]

## 输入 / 输出 / 行为
<详细描述函数签名、组件 props、API 入参出参、UI 行为，含边界条件>

## 技术约束
- 必须用：[stack, e.g. React 18, TypeScript strict]
- 必须遵守项目根 `AGENTS.md` 全部规则
- 不得引入新依赖（除非显式列出）：[allowed_deps]
- 不得用：[forbidden patterns, e.g. any, @ts-ignore]

## 测试要求（TDD 强制时必填）
- 顺序：**先写 failing test → commit → 再写实现 → commit**
- 测试框架：[vitest / jest / pytest]
- 必须覆盖：
  - [ ] happy path
  - [ ] 边界 1：[describe]
  - [ ] 边界 2：[describe]
  - [ ] 错误处理：[describe]
- 跑命令：`<test command>`

## 验收 hard gates（必须全部满足才能通过 Claude review）
- [ ] 功能：[verifiable assertion]
- [ ] 类型检查 pass：`<typecheck command>`
- [ ] Lint pass：`<lint command>`
- [ ] 测试 pass：`<test command>`
- [ ] 没有 TODO / FIXME / mock 残留（除非 SPEC 允许）
- [ ] 没改 SPEC「范围」之外的文件
- [ ] 没引入未授权依赖

## 报告要求
完成后必须输出 JSON 块（不要包在 markdown 里，独立块）：

\`\`\`json
{
  "files_changed": [
    {"path": "...", "action": "added|modified|deleted", "lines_added": 0, "lines_deleted": 0}
  ],
  "deviations": [
    {"location": "...", "from_spec": "...", "actual": "...", "reason": "..."}
  ],
  "todos_left": ["..."],
  "new_deps": [{"name": "...", "version": "...", "why": "..."}],
  "tests_written_first": true,
  "tests_passed": true,
  "test_command": "...",
  "test_output_tail": "...",
  "spec_compliance": "full | partial | broken",
  "self_assessment": "..."
}
\`\`\`

字段说明：
- `tests_written_first`：是否真的先写 failing test 再写实现（git history 应能验证）
- `spec_compliance`：
  - `full` — 完全按 SPEC，无 deviations
  - `partial` — 有 deviations 但整体功能可用
  - `broken` — 偏离过大或 SPEC 无法实现
```

## 写 SPEC 的硬约束

1. **不要省略「范围」**：没写"涉及文件"就派 Codex = 给 Codex 自由发挥
2. **不要省略「验收 hard gates」**：没明确 gate 就 review 不出来
3. **不要省略「报告要求」**：没要求 JSON 报告 = Claude review 拿不到结构化数据
4. **TDD 必填**：除非命中 TDD Whitelist，"测试要求"段不能省

## 何时可以省略某段

- 改动只动 1-2 个文件 → "范围" 可以简写但不能省
- 不需要测试（命中 TDD Whitelist）→ "测试要求" 段标 `n/a` 并写明命中哪条 whitelist
- 不需要新依赖 → `allowed_deps: []` 显式标空数组
