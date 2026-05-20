# TODO Driver — Stage 1 Prompt（spec drafter）

把整篇内容作为 prompt 喂给 agent。**调用前确保 agent 的 cwd 已经在目标项目根目录**（cron 脚本里 `cd <project>` 一下即可）。

---

你正在为这个项目维护一条 "TODO → spec → dev → merge" 自动化流水线。本轮你只负责 **Stage 1：把下一个 pending 的 TODO 转化成 spec 文档**。

## 目标

扫描 `TODO.md`，找第一个**带 slug 但还没有对应 spec 文件**的项，按规范出一份 spec 写到 `docs/spec/<slug>.md`。如果没有可处理项，**清洁退出**，不写任何文件、不报错。

## 执行算法（严格按顺序）

### Step 1：环境 sanity check

```bash
test -f TODO.md || { echo "no TODO.md, exit clean"; exit 0; }
test -d docs/spec || mkdir -p docs/spec docs/spec/_done
grep -q "^\.worktrees/" .gitignore 2>/dev/null || echo "WARN: .gitignore should contain .worktrees/"
```

不要因为 `.gitignore` 缺项而退出 —— 写到 spec 的 "风险" 区段提示用户即可。

### Step 2：找下一个 pending TODO

并行扫两个来源：
- `TODO.md` 中所有 `- [ ] \`<slug>\` ...` 行，按从上到下顺序提取 `(slug, title, hint)` 三元组
- `docs/spec/` 下已存在的所有 `.md` 文件名（去掉 `.md`），构成 "已有 spec 的 slug 集合"

第一个**不在已有集合**的 slug 就是本轮目标。`docs/spec/_done/` 不算（已 merged 的不重做）。

**找不到** → 输出 `nothing to do (all TODOs have specs)` 并退出。

**slug 格式校验**：必须匹配 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`。不合法 → 跳过这条，继续找下一条；同时把违规 slug 列到最后的 IM 通知里让用户修。

### Step 3：理解项目

按顺序读（缺哪个跳哪个）：
1. `AGENTS.md`（首选工程规范源）
2. `CLAUDE.md`（次选）
3. `README.md` / `README.zh-CN.md`（产品上下文）
4. `package.json` / `Cargo.toml` / `pyproject.toml`（技术栈）

不要读整个 src/。只在评估 "影响范围" 时，针对 TODO 提到的具体模块做**最小**的 Grep + Read。每次 Read 不超过 100 行。**总文件读取数 ≤ 15**，超了就停下用已有信息出 spec。

### Step 4：估算改动规模 + 判定是否 epic

按下列启发规则估算改动**文件数**和**总行数**：

| 信号 | 估算 |
|---|---|
| TODO 文本含 "新增功能 / 加一个 ... 按钮 / 加一个设置" | 通常 ≤ 5 文件 |
| 含 "重构 / 抽象 / 命名空间化 / 跨模块" | ≥ 10 文件 |
| 含 "支持 ... 切换 / 多种 ..." | 经常是 epic |
| 含 "迁移 / 升级 / 重写" | 几乎一定是 epic |
| 涉及全局样式（如 globals.css）的命名规则改动 | ≥ 8 文件 |

**Epic 判定**：估算 > 10 文件 **或** > 500 行 **或** 涉及 "store + UI + 全局样式" 三层中两层及以上。

### Step 5a：Epic 路径 —— 产出 decomposition spec

写 `docs/spec/<slug>.md`：

```yaml
---
id: <slug>
title: <从 TODO 文本提取>
status: draft
kind: decomposition
epic: true
depends_on: []
attempts: 0
self_approved: false
created: <today>
updated: <today>
---
```

正文写：
- **目标**：epic 整体目标
- **拆分理由**：为什么单次 spec 装不下
- **子任务清单**：3-7 个，每个一句话 + 估算依赖关系
- **建议执行顺序**：依赖图

同时**修改 TODO.md**：把原 TODO 后面缩进追加子项，例如：

```md
- [ ] `style-switch` 设计风格切换 — (epic, 已拆分 → docs/spec/style-switch.md)
  - [ ] `style-tokens-namespace` punk-* 变量改命名空间
  - [ ] `style-toggle-ui` 设置页加风格选择器
  - [ ] `style-pack-minimal` 实现"简约"风格包
```

子 slug 由你定，规则：`<epic-slug>-<short-suffix>`。

**Decomposition spec 永远不自审**（`self_approved: false`），必须人审。

### Step 5b：Implementation 路径 —— 产出实施 spec

```yaml
---
id: <slug>
title: <从 TODO 提取>
status: <draft 或 approved，由 Step 6 决定>
kind: implementation
epic: false
depends_on: []   # 如果 TODO 显式说"需要先做 X"，把 X 的 slug 填进去
attempts: 0
self_approved: <Step 6 决定>
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

### Step 6：自审决策

按 README 里的 6 条硬条件**逐条核对**。**全部 yes** 才能 `self_approved: true` 并把 `status: approved`。

判定时把每条评估结果写进 `self_approved_reasons` 列表，例如：

```yaml
self_approved: true
self_approved_reasons:
  - "改动 3 文件 / 估算 80 行 / 仅 CSS + 一个 store 字段"
  - "不触及 auth/payments/加密/迁移"
  - "方案选项只有 A 一个明确选择，无业务二选一"
  - "无新依赖（仅用 zustand 已有 API）"
  - "无公开 API 变更"
  - "非 epic（implementation kind）"
```

**任一不满足** → `self_approved: false`，`status: draft`，且不写 `self_approved_reasons`，但要在 "Decisions log" 区段写一句"自审未过，原因：xxx"。

### Step 7：写 Decisions log

文末附 `## Decisions log` 区段，本次留一条：

```md
- **<today>**: 初版 spec，<one-line summary of key decision>
```

### Step 8：通知

输出一段简短摘要（不超 8 行）给标准输出，包含：
- 处理的 slug
- 路径（implementation / decomposition）
- self_approved 是否通过
- spec 文件路径
- 用户下一步要做什么（"改 status: approved" 或 "审核后改 status: approved"）
- 如果 Step 2 跳过了违规 slug 也列出来

不要主动调用任何 IM API —— cron 包装层会接管 stdout 转发给用户。

## 边界

- **不要** 跑测试、lint、build
- **不要** 改任何代码（只改 TODO.md 和写 docs/spec/）
- **不要** 创建 worktree 或分支
- **不要** push 任何东西
- **不要** 修改已经存在的 spec 文件（如果误判进入 Step 5 但 spec 已存在，stop）
- 单次最多产出 1 个 spec。下次 cron 拉起来再处理下一个。

## 失败处理

- 找不到 TODO.md / docs/spec/ 没法 mkdir → clean exit code 0，输出原因
- 读项目文件超过 15 个还没估算清楚 → 强行用当前信息出 spec，在 "风险" 区段写"信息不足"
- 任何写文件失败 → 报错 exit code 非 0，不要留下半成品 spec（用 temp file + mv 模式）

## 输出契约（给 cron 包装层）

stdout 最后一行必须是 JSON 单行：

```json
{"status":"drafted","slug":"<slug>","kind":"implementation","self_approved":true,"spec_path":"docs/spec/<slug>.md"}
```

或没活干时：

```json
{"status":"idle","reason":"all TODOs have specs"}
```

或拒绝时：

```json
{"status":"skipped","reason":"invalid slug format","slugs":["BadSlug"]}
```

cron 程序读这行 JSON 决定要不要 push 通知 + 怎么填消息模板。
