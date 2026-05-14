# PLAN.md 模板

> 把 GOAL.md 的 Objective 拆成可独立验证的 Phases，每个 Phase 含 milestone + 验证。

```md
# Plan: <task-id>

## Phase 1: <子目标 1，2-4 小时可完成>

### Milestones
- [ ] M1.1: <具体动作，能用文件路径或 grep 模式验证>
- [ ] M1.2: <...>

### Verification (run after Phase 1 done)
- [ ] pnpm test --filter <subset>
- [ ] git diff --stat | wc -l ≤ 20

### Rollback
- 如果本 Phase 验证失败，回退方式：git reset --hard HEAD~<n>

---

## Phase 2: <子目标 2>

### Milestones
- [ ] M2.1: ...
- [ ] M2.2: ...

### Verification
- [ ] ...

### Rollback
- ...

---

## Phase N: <最后一个 Phase，必须包含 Acceptance Criteria 全验证>

### Milestones
- [ ] MN.1: ...

### Verification
- [ ] **跑完 EVAL.md 中所有 Required Commands**
- [ ] **逐条核对 GOAL.md 的 Acceptance Criteria**

### Final Check
- [ ] 在 STATUS.md 末尾写入 `GOAL_DONE`（必须这 9 个字符）
```

## 写 Plan 的硬约束

1. **每个 Phase 必须有自己的 Verification**——不能"等所有 Phase 完了一起验"
2. **每个 Milestone 必须能独立验证**——能用 grep / file exist / test pass 之一
3. **每个 Phase 必须有 Rollback 路径**——失败时知道怎么回滚
4. **不要预留模糊步骤**：禁止 "M3.5: 处理边界情况"——必须列具体 case
5. **Phase 数 ≤ 7**——超过说明 GOAL 拆得不够，可能要拆成多个 task
