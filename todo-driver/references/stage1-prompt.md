# Spec Drafter Prompt

把整篇内容作为 prompt 喂给 agent。调用前确保 agent 的 cwd 在目标项目根目录。

---

你的任务：为指定的功能/任务起草一份 spec 文档写到 `docs/spec/<slug>.md`。

## 输入

调用方必须提供：

- `slug`：kebab-case 唯一标识，正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`
- `title`：一行短标题
- `summary`：一两句话讲清楚要做什么
- 可选 `hints`：偏好或约束（如"用 zustand"、"不能引入新依赖"）

## 执行算法（严格按顺序）

### Step 1：环境 sanity check

```bash
test -d docs/spec || mkdir -p docs/spec
test -f docs/spec/<slug>.md && { echo "spec already exists, stop"; exit 0; }
```

spec 已存在 → **不覆盖**，stop。

### Step 2：理解项目

按顺序读（缺哪个跳哪个）：

1. `AGENTS.md`（首选工程规范源）
2. `CLAUDE.md`（次选）
3. `README.md` / `README.zh-CN.md`（产品上下文）
4. `package.json` / `Cargo.toml` / `pyproject.toml`（技术栈）

不要读整个 src/。只针对 `summary` / `hints` 提到的具体模块做**最小**的 Grep + Read。每次 Read 不超过 100 行。**总文件读取数 ≤ 15**，超了就停下用已有信息出 spec。

### Step 3：估算改动规模

按下列启发规则估算改动**文件数**和**总行数**，写进 Step 4 的"影响范围"区段：

| 信号 | 估算 |
|---|---|
| summary 含 "新增功能 / 加一个 ... 按钮 / 加一个设置" | 通常 ≤ 5 文件 |
| 含 "重构 / 抽象 / 命名空间化 / 跨模块" | ≥ 10 文件 |
| 含 "迁移 / 升级 / 重写" | 大改 |
| 涉及全局样式（如 globals.css）的命名规则改动 | ≥ 8 文件 |

### Step 4：产出 spec

frontmatter：

```yaml
---
id: <slug>
title: <title>
status: <draft 或 approved，由 Step 5 决定>
self_approved: <Step 5 决定>
self_approved_reasons: []   # 仅 self_approved=true 时填
created: <today>
updated: <today>
---
```

正文按这 7 个固定标题写（**全写**，没有的也保留标题写"无"）：

1. **目标** — 做完后用户能看到/用到的具体改变（一两句）
2. **现状** — 引用具体文件:行号，说明当前代码状态
3. **方案选项** — 列 1-3 个备选，每个写优劣
4. **推荐方案 + 理由** — 选哪个，为什么。理由必须可被反驳/检验
5. **影响范围** —
   - 改动文件清单（带行数估算）
   - 总估算行数
   - 新增依赖（无 → 写"无"）
   - 影响公开 API / 类型（无 → 写"无"）
6. **验收标准** — `- [ ]` checkbox 列表，**每条必须可测**。强制包含末尾两条："所有现有测试通过"、"lint clean / build success"
7. **风险** — 潜在坑 + 回滚方案

### Step 5：自审决策

**全部满足**才能 `self_approved: true` 且 `status: approved`：

1. 改动 ≤ 5 文件 且 ≤ 200 行
2. 不触及 auth / payments / 加密 / 数据迁移 / 跨模块重构
3. 方案选项里所有选项**显著优劣分明**（无业务判断二选一）
4. 不引入新依赖
5. 不修改公开 API / 类型签名

判定时把每条评估结果写进 `self_approved_reasons` 列表：

```yaml
self_approved: true
self_approved_reasons:
  - "改动 3 文件 / 估算 80 行 / 仅 CSS + 一个 store 字段"
  - "不触及 auth/payments/加密/迁移"
  - "方案选项只有 A 一个明确选择，无业务二选一"
  - "无新依赖（仅用 zustand 已有 API）"
  - "无公开 API 变更"
```

**任一不满足** → `self_approved: false`，`status: draft`，不写 `self_approved_reasons`，但在 "Decisions log" 区段写一句"自审未过，原因：xxx"。

### Step 6：写 Decisions log

文末附 `## Decisions log` 区段，本次留一条：

```md
- **<today>**: 初版 spec，<one-line summary of key decision>
```

### Step 7：报告

输出简短摘要（不超 8 行），包含：

- 处理的 slug
- self_approved 是否通过
- spec 文件路径
- 用户下一步要做什么（"改 status: approved" 或 "审核后改 status: approved"）

## 边界

- **不要** 跑测试、lint、build
- **不要** 改任何代码（只写 `docs/spec/<slug>.md`）
- **不要** 创建 worktree 或分支
- **不要** push 任何东西
- **不要** 修改已经存在的 spec 文件（Step 1 检查到已存在直接 stop）
- 单次最多产出 1 个 spec

## 失败处理

- `docs/spec/` 没法 mkdir → 报错 exit code 非 0
- 读项目文件超过 15 个还没估算清楚 → 用当前信息出 spec，在 "风险" 区段写"信息不足"
- 任何写文件失败 → 报错 exit code 非 0，不要留下半成品 spec（用 temp file + mv 模式）
