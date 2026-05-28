# director-architect — Output Contract Markdown 模板

> 完整 markdown 报告模板。SKILL.md 主体只保留对 `references/output-contract-schema.md`
> 的引用 + 本 skill 扩展字段;详细内容(research / land)模板整段保留在本文件,
> 主流程要展示给用户或 handoff 给下游时再 lazy-load 读。

## research 输出(所有 mode 都必须输出,强制全字段)

```md
## Director-Architect Research Report

### 任务理解
- 用户原话:
- 内部路径判定: research-only | research+approval+land | research+mirror+approval+land | land-only
- 触发信号: "审一下" | "梳理" | "按 X 项目" | "已经定好了" | 其他: <原文>

### 项目规则现状(**带证据 [file:line]**)
- 入口文件: <CONTRIBUTING.md / RULE.md / AGENTS.md / ... 列路径 + 行数>
- docs/ 树: <实际目录结构>
- 重复内容: <具体片段 + 出现位置>
- 放错层内容: <对照分类模型说明>
- 缺失领域: <list>

### 识别到的技术栈
- 自动识别: <stack list + 元信息来源>
- 用户指定: <list 或 "无">
- 最终栈清单: <merged>

### 参与联合评估的 skill 清单
- <skill-name> (<来源路径>) — 结论: <一句话>
- <skill-name> (<来源路径>) — 结论: ...
- **未覆盖的栈**: <list 或 "无">

### 联合评估结果(按四类问题分)
- 规范缺失: <list>
- 规范偏差: <list>
- 规范冗余: <list>
- 规范放错层: <list>

### 参考项目对齐(**仅当 Step 5 跑了**)
- 参考项目路径: <path 或 URL>
- 借鉴的模式: <list>
- 不适用的部分 + 理由: <list>

### 决策记录(**自决必须留痕,缺失 = Red Flag**)
- 冲突点 1: <best-practice skill A 说 X,B 说 Y>
  - 备选方案: <list>
  - 选定方案: <which>
  - 理由: <why>
- 冲突点 2: ...
- 内部权衡 1: <例如 "testing 单独分域 vs 合入 coding">
  - 备选方案 / 选定 / 理由

### 目标结构
- 总入口: <path>
- 分域目录:
  - <domain>/
    - index.md(导航职责: ...)
    - rules.md(总纲职责: ...)
    - <二级文件 1>: <职责>
    - ...
- 阅读优先级 / AI 路由: <说明 AI 先读什么、再读什么>

### 文件级变更清单(diff 预览)
- 新增: <path>
- 修改: <path + 摘要>
- 迁移: <from → to + 是否真搬正文>
- 合并: <多个 → 一个>
- 删除: <path>

### 风险与权衡
- 风险 1: <如 "迁移后大量历史引用需修">
- 权衡 1: <如 "选了 strict mode tsconfig 会增加现存 type errors">

### Next Step
- 若 research-only: 等用户决定是否进入落地
- 若 research+approval+land: **Approval Gate** — 等用户明确 yes
- 若 land-only: 已回放 plan,等用户确认这是最终方案

### 明确不在职责内(告知 orchestrator)
- README / CHANGELOG → flow-project-finish
- 视觉 token 具体取值 → director-design
- 单 skill 自身写法 → skill-creator / writing-skills
- 写生产代码 → director-frontend
```

## land 输出(**仅当 Land Phase 执行后**)

```md
## Director-Architect Land Report

### 批准证据引用
- 用户原话: <quote 不含糊的批准表态>
- 时间戳:

### 改了哪些文件
- 新增: <path>
- 修改: <path>
- 迁移: <from → to>
- 合并: <多个 → 一个>
- 删除: <path>

### 委派情况(哪些子任务调了哪些 skill)
- clean-commit: <invoked / not invoked>
- 其他: <如调了某 best-practice skill 出具体规则文本>
- 自做: <list>

### 遗留
- 待处理的历史引用: <list>
- 未覆盖的栈: <list>

### Delivery Check
- [ ] CONTRIBUTING.md 只做总入口(无正文堆积)
- [ ] 每个领域目录同时存在 index.md + rules.md
- [ ] 无两套同时有效的规则体系
- [ ] 项目实际栈都被某个规则域覆盖(或显式标"未覆盖")
- [ ] 决策记录已在 research 报告留痕

### 下一步建议
```

## 字段约定

- **research 报告**落盘位置: `.agent/jobs/director-architect-<task-slug>/research.md`
- **land 报告**落盘位置: `.agent/jobs/director-architect-<task-slug>/land.md`
- artifact_path JSON 字段指向其中一份(优先 land,无 land 则 research)
- 完整字段语义见 `references/output-contract-schema.md` §基线 JSON Schema
