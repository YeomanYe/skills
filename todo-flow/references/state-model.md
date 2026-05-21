# TODO Flow — 系统说明

把项目 TODO 串成 "draft spec → review → dev → review → done" 流水线。
**Stage 0/3 走 skill（人触发），Stage 1/2 走 cron + 这里的 prompt**。

---

## 文件状态机（纯文件系统推断，零外部 DB）

```
pending          docs/spec/<slug>.md 不存在
                       │ stage 1 写 spec
                       ▼
spec-drafted     status: draft（待人审）
                       │ 人 or agent 自审 → 改成 approved
                       ▼
spec-approved    status: approved
                       │ stage 2 拾起
                       ▼
dev-in-progress  branch todo/<slug> 存在 + status 仍是 approved
                       │ stage 2 跑完
                       ▼
dev-done         status: ready-for-review        ← stage 2 输出
verify-pass      status: verified                 ← stage 3 输出
verify-fail      status: verify-failed            ← stage 3 输出
                       │ todo-flow done: review pass + squash merge
                       ▼
done             spec 被移到 docs/spec/_done/，branch 删除，TODO 标 [x]
```

**特殊态**：`status: blocked` —— `attempts >= 3` 后自动标，需人介入。

---

## TODO.md 格式约定

每条 TODO **必须**带反引号包裹的 slug，slug 在 repo 内唯一：

```md
- [ ] `theme-toggle` 主题切换 — 支持深色/浅色/跟随系统三态
- [ ] `style-switch` 设计风格切换 — punk-* 命名空间化，未来支持简约/拟物
```

- `- [ ]` = 系统标记的未完成（pending/draft/approved/in-progress/ready）
- `- [x]` = 系统标记的已完成（由 todo-flow done 在 squash merge 后改）
- slug 命名规则：kebab-case，3-30 字符，仅 `a-z0-9-`
- 无 slug 的旧 TODO 会被 stage 1 跳过（不处理）

**Epic 拆分时**：父 TODO 缩进显示子项

```md
- [ ] `payment-system` 支付系统 — (epic, 由 stage 1 拆分)
  - [ ] `payment-stripe-setup` Stripe 接入
  - [ ] `payment-webhook` 接收 webhook
  - [ ] `payment-receipt` 生成发票
```

父 epic 由 skill 3 在所有子项 done 后自动 close。

---

## docs/spec/&lt;slug&gt;.md 格式

```yaml
---
id: theme-toggle
title: 主题切换支持深色/浅色/跟随系统
status: draft | approved | ready-for-review | verified | verify-failed | blocked
kind: implementation | decomposition
epic: false                  # 仅 decomposition kind 时可能 true
depends_on: []               # [<slug>, ...] 必须全部 done 后才能进 dev
attempts: 0                  # stage 2 跑过几次，>=3 自动 blocked
self_approved: false         # stage 1 是否自审通过
self_approved_reasons: []    # 仅 self_approved=true 时填
created: 2026-05-20
updated: 2026-05-20
---

## 目标
<一句话讲清楚做完这个 TODO 之后用户看到 / 用到什么>

## 现状
<相关代码 / 文件 / 模块的当前状态，引用具体行号>

## 方案选项
<列出可选方案，每个写优劣>

### 选项 A: ...
### 选项 B: ...

## 推荐方案 + 理由
<选哪个，为什么。对比 A/B 的关键论据>

## 影响范围
- 改动文件: <清单>
- 估算改动行数: <数字>
- 新增依赖: <清单或 "无">
- 影响公开 API / 类型: <说明或 "无">

## 验收标准
- [ ] <可测的标准 1>
- [ ] <可测的标准 2>
- [ ] 所有现有测试通过
- [ ] lint clean / build success

## 风险
<潜在坑、回滚方案>

## Decisions log
- **2026-05-20**: 选了选项 A 因为 ...
- **2026-05-22**: review feedback: ... → 修了 ...（review fail 后回到 approved 时追加）
```

---

## Stage 2 失败后的日志格式

stage 2 dev 跑失败时，**追加**到 spec 末尾：

```md
## Attempt 1 failure (2026-05-20T14:23Z)
- 错误: `pnpm test` 失败 in `src/foo.test.ts:42`
- 原因: <agent 自己写的诊断>
- 已尝试: <采取的修复手段>
- 卡在哪: <停下的那一步>
```

attempts 字段 +1。`attempts >= 3` 后自动 `status: blocked`。

---

## 自审通过的硬条件（stage 1 写 `self_approved: true` 的门槛）

**全部满足**才能自审通过：

1. 改动 ≤ 5 文件 且 ≤ 200 行
2. 不触及 auth / payments / 加密 / 数据迁移 / 跨模块重构
3. spec 的"方案选项"区块里所有选项**显著优劣分明**（无业务判断二选一）
4. 不引入新依赖
5. 不修改公开 API / 类型签名
6. 不是 epic（kind != decomposition）

任一不满足 → `status: draft`，等人审。

---

## 工程规范来源（stage 3 review 引用的 ground truth）

按顺序找：

1. `<project-root>/AGENTS.md` ← 首选
2. `<project-root>/CLAUDE.md` ← 退而求其次
3. 都没有 → 仅做通用检查（lint、typecheck、tests、无新依赖）

---

## Worktree 与分支

- worktree 路径：`<project-root>/.worktrees/<slug>`
- branch 命名：`todo/<slug>`
- branch 基线：`main`
- 推送：`git push -u origin todo/<slug>`
- done 策略：squash merge（todo-flow done 自动）
- done 后：删 branch + 删 worktree + 移 spec 到 `_done/`

**确保 `.gitignore` 包含 `.worktrees/`**。stage 1 第一次跑时会检查并提示。

---

## 调用拓扑

```
你的 cron 程序
   │
   ├─ 6h 一次 → 用 todo-flow-stage1-spec.md 拉起 agent
   │             agent 扫 TODO.md → 出 spec → IM 通知你审
   │
   └─ 30min 一次 → 用 todo-flow-stage2-dev.md 拉起 agent
                  agent 扫 spec/*.md → 找 approved → 开 worktree → 实现 → 推 branch → IM 通知

你（手动）
   ├─ skill `todo-flow add`       新建 TODO（带 slug）
   ├─ 改 spec status: approved    审通过让 stage 2 拾起
   └─ skill `todo-flow done`      review + squash merge + 归档
```

频率建议：
- stage 1（出 spec）：6 小时一次，单次只处理 1 个 TODO
- stage 2（开发）：30 分钟一次，单次只处理 1 个 spec

两个 prompt 都设计成幂等：扫不到可处理项就清洁退出，重复调用零副作用。
