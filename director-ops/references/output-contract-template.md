# Output Contract — director-ops 完整 markdown 报告模板

> 本文件保存 `director-ops` 完整 markdown 报告模板,**整段照搬主 SKILL.md 原内联模板**,
> 不简化、不删字段。
>
> JSON 基线规范见 `references/output-contract-schema.md`。
> 主流程只在需要展示给用户 / 移交下游时 `Read` 本模板路径;
> subagent 不要在 stdout 复述 markdown 全文(违反 dispatcher 契约)。

## 落盘位置

`.agent/jobs/director-ops-<tool>-<mode>/output.md`(例 `director-ops-nodejs-install`)

## 完整 markdown 报告模板

```md
## Director-Ops Report

### 任务理解
- 用户原话:
- mode 判定: install | uninstall
- 目标软件:

### 环境
- OS / 版本 / 架构:
- 包管理器: <可用列表>
- 目标软件当前状态: 已装 v<x> | 未装

### Question Gate
- 问题数: 0 | 1 | 2 | 3
- 问题清单:
  - Q1: ...(默认值: ...)
- 用户回复: <quote 或 "用默认值">
- 影响的执行决策: <list>

### 证据采集(对照 references/evidence-discovery.md)
- 探测命令: <list 用了哪些 which / brew list / rg 知识库>
- 命中: <list 知识库路径 + 命令输出摘要>
- 缺失: <list 没找到的证据 + 影响>
- 适用性判断: <list 资料平台/版本/路径是否匹配当前系统>
- 降级: <若资料只覆盖部分平台,明示降级原因>

### 资料来源
- 本地知识库: hit <path> | miss
- 用户提供: yes <link> | no
- 网络搜索: 用了 <URL> | 没用
- install 候选方式: <方式 1/2/3... + 可信度/适配性/升级卸载方式摘要> | n/a
- 推荐方式: <method + why> | n/a
- 适用性判断（uninstall）: <资料与当前系统是否匹配 / 推断说明> | n/a

### 计划
- 步骤数: <n>
- 自动 / 半自动 / 手动: <a>/<b>/<c>
- install 候选方式对比: <已列出 | 未列出 + 原因> | n/a
- 破坏性环节（uninstall）: 备份路径 <...> / 拟删数据 <...> | n/a

### 用户确认
- 时间: <ts>
- 确认方式: <quote of user reply>

### 执行结果
- 完成步骤: <n>/<total>
- 失败步骤: <list with errors>
- 备份完成（uninstall）: yes <path> | n/a

### 验证
- install: 版本 <pass + version | fail> / 基本功能 <pass | fail>
- uninstall: 主命令已移除 <pass | fail> / 包管理器已不列出 <pass | fail> / 残留已清理 <yes | 保留原因>

### 7 维 Quality Audit(**每维必须含 `[command 输出摘要 / 知识库路径]` 佐证**)
- [✓] 环境探测充分性 — N/5 — `[Step 1 命令清单 + 关键输出]`
- [✓] 资料来源可信 — N/5 — `[本地 + 网络来源 + install 候选方式枚举 / uninstall 适用性判断]`
- [✓] 计划可执行性 — N/5 — `[每步类型/命令/风险标注情况]`
- [✓] 用户确认清晰度 — N/5 — `[用户原话 quote + sudo 项是否明示]`
- [✓] 执行成功率 — N/5 — `[完成/失败步骤数 + 失败定位]`
- [✓] 验证完整性 — N/5 — `[验证命令清单 + 覆盖项]`
- [✓] 知识库记录质量 — N/5 — `[知识库路径 + 是否含日期/版本/踩坑]`
- **aggregate**: X.X / 5
- **verdict**: installed-clean | installed-with-warnings | partial | failed

### 知识库
- 路径: ~/Documents/knowledge/<tool>-{install|uninstall}.md
- 状态: 新建 | 更新

### 结论
- install: 可用 yes | no
- uninstall: 已卸载且系统正常 yes | no
- 剩余问题 / 手动步骤:
```

如有失败或手动步骤,明确列出,**不夸大**。
