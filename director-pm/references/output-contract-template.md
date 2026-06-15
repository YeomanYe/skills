# Output Contract Template — director-pm 完整 markdown 报告模板

> 本文件是 `director-pm` 的"人类读"完整 markdown 报告模板。主体 SKILL.md `## Output Contract`
> 段只保留 JSON 基线字段引用 + 扩展字段声明；完整报告由 subagent 落盘到
> `.agent/jobs/director-pm-<task-slug>/output.md`，主流程要展示 / 移交下游时再 `Read artifact_path`。
> 通用 JSON 基线字段见 `references/output-contract-schema.md`。

## 完整 markdown 报告模板

```md
## Director-PM Report

### 任务理解
- 用户原话:
- mode 判定: clarify | prd | prioritize | critique
- evidence: <需求来源 / 数据 / 竞品 / assumption(待验证)>

### 产品判断
（按 mode 填）
- clarify: 问题陈述 / 目标用户 / 核心价值 / 成功指标 / 范围(in·out·non-goal)
- prd: 产品目标 / 用户故事 / 验收标准 AC / 范围 / 非目标 / 开放问题
- prioritize: 排序表(RICE 或 MoSCoW) + 每项依据 + **先不做列**
- critique: N 维评分 + verdict + must-fix / should-trim

### 取舍留痕（强制）
- 砍掉了什么 + 为什么砍:
- 选定优先级的依据:
- best-practice / 数据 / 假设的来源:

### 假设与待验证项
- <假设 1 + 怎么验证（用户访谈 / 数据 / 竞品）>

### Next Step / 移交
- handoff 给: director-design（设计）/ director-architect（架构）/ flow-dev-task（实现）
- 移交时带: objective / 用户故事 / AC / 范围

### 不在职责内（明确边界）
- 技术栈 → director-architect / 视觉 → director-design / 开工 intake → project-prep
```

每个评分 / 结论必须含 `[需求来源 / 证据路径 / 假设标注]`（佐证格式见 `references/evidence-discovery.md`）。
