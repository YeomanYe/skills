# EVAL.md 模板

> 验证命令清单 + 质量门 + Reviewer rubric。**Goal Codex 和 Reviewer Codex 都读这份。**

```md
# Evaluation: <task-id>

## Required Commands
**每个 milestone 完成后必须依次跑**（按下面的顺序）：

```bash
# 类型检查
pnpm tsc --noEmit                      # or: npx tsc --noEmit / cargo check / go vet

# Lint
pnpm lint                              # or: npm run lint / cargo clippy

# 测试
pnpm test --run                        # or: npm test / cargo test / go test ./...

# Build
pnpm build                             # or: npm run build / cargo build --release
```

输出全部 append 到 `.agent/tasks/<task-id>/logs/verify.log`，并按下表落到 `review-input/`：

| 命令 | 输出文件 |
|---|---|
| typecheck | `review-input/lint.txt` |
| lint | 同上（合并） |
| test | `review-input/test.txt` |
| build | `review-input/build.txt` |

## Quality Gates
**任一不过 → 不能写 GOAL_DONE**：

- [ ] typecheck pass（exit 0，无 error）
- [ ] lint pass（exit 0，无 error；warning 可接受 ≤ 5 条）
- [ ] test pass（所有现有测试通过 + 新加的测试通过）
- [ ] build pass（exit 0）
- [ ] git diff --stat 显示**只动了 GOAL.md「Scope」白名单内文件**
- [ ] 没有未授权的新依赖（`git diff package.json` 干净 或 dep 在 GOAL.md 明示）
- [ ] 没有 `TODO` / `FIXME` / `mock` 关键词新增（除非 GOAL.md 允许）
- [ ] 如果 UI 改动 → 必须有 Playwright 截图存到 `review-input/screenshots/`

## Reviewer Rubric
**Reviewer Codex 按这 4 维度 + GOAL.md 中 `custom_dimensions` 的扩展维度打分（各 1-5 分），全部 ≥ 4 才能 verdict=pass**：

### 0. 扩展维度（如果 GOAL.md `custom_dimensions` 段非空）

按 GOAL.md `custom_dimensions` 列表逐项评分（1-5）。每个维度的 1/3/5 锚点见 `references/score-rubric-extensions.md`。
**禁止**把 1-5 改成 1-10（mini-review 易犯，反复强调）。

### 1. 正确性 (Correctness)
- 实现是否真的满足 GOAL.md 的 Acceptance Criteria
- 边界条件是否覆盖（空输入、错误输入、并发）
- 是否引入回归（diff 范围外是否被影响）

### 2. 可维护性 (Maintainability)
- 命名清晰
- 抽象合理（无过度抽象 + 无重复代码）
- 函数 < 50 行（除非 GOAL.md 允许）
- 注释只解释 WHY 不解释 WHAT

### 3. 用户体验 (UX) — 仅 UI 改动适用
- 错误状态、空状态、加载状态是否处理
- 截图显示无明显视觉缺陷
- 键盘可达性、屏幕阅读器友好性

### 4. 风险 (Risk)
- 是否引入了未授权的破坏性操作
- 是否有 secret / token 泄漏
- 是否动了 GOAL.md「Non-goals」内的代码
- 是否绕开了 EVAL.md 的硬门

## 完成判定（GOAL_DONE 写入条件）

Goal Codex **必须同时满足**才能写入 `GOAL_DONE`：

1. ✅ 所有 Required Commands 都跑过且 pass
2. ✅ Quality Gates 全部打勾
3. ✅ GOAL.md 的所有 Acceptance Criteria 都打勾
4. ✅ STATUS.md 最后一段记录了完成 timestamp + Phase N 完成 + 验证结果摘要

写入格式（必须这一行，方便 health-check 检测）：

```
GOAL_DONE @ 2026-05-14T12:34:56Z
```
```

## 通用模板说明

- 上面的 `pnpm test` / `cargo test` 等命令模板，按项目实际栈替换
- 如果项目无测试框架 → 在 EVAL.md 显式声明 "No test framework, manual smoke test required" 并把 smoke test 步骤写进 Quality Gates
- 如果项目无 build → 同上声明
- Reviewer Rubric 的 4 维度可裁剪（比如纯后端无 UI 任务可去掉 #3）
