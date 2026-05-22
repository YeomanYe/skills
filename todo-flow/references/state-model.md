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
needs-rework     status: needs-rework             ← revise mode 输出,stage 2 再次拾起按 `## Rework instructions` 重做
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
status: draft | approved | ready-for-review | verified | verify-failed | needs-rework | blocked
change_type: added | changed | fixed   # 可选,done mode 写 CHANGELOG 时用
bump_hint: patch | minor | major       # 可选,done mode 决定 semver bump 时用(优先级低于 --version 入参)
verified_at: <ISO timestamp>            # stage3 verified 时写
verify_failed_at: <ISO timestamp>       # stage3 verify-failed 时写
kind: implementation | decomposition
epic: false                  # 仅 decomposition kind 时可能 true
depends_on: []               # [<slug>, ...] 必须全部 done 后才能进 dev
attempts: 0                  # stage 2 IMPL_FAIL 累积次数(仅 stage2 +1,不算 stage3 verify-failed),>=3 自动 blocked
verify_attempts: 0           # stage 3 verify-failed 累积次数(独立计数,不触发 blocked,只供 done mode 评估可信度)
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

## 3 stage 通用 JSON 输出契约(v2 新,硬约束)

所有 stage(1/2/3)的 Output Contract JSON 都**必须**含以下"通用字段",外层工具统一靠这套字段解析。各 stage 可追加自己的专属字段(如 stage3 的 `hard_gates` / `visual_check`),但通用字段不能缺:

| 字段 | 类型 | 含义 |
|---|---|---|
| `stage` | int | 1 / 2 / 3 |
| `verdict` | string | success / failure / verified / verify-failed / idle / skipped |
| `slug` | string \| null | 当前 spec id,idle 时 null |
| `project` | string \| null | 工程绝对路径 |
| `summary` | string | IM 主消息正文,≤ 200 字 |
| `im_attach` | array | 外层必发附件清单 `[{type, path, caption?}]`,可空 |
| `local_artifacts` | array | 用户查阅路径(IM 不发) `[{type, path}]`,可空 |
| `errors` | array | 失败原因 `[{step, exit?, tail}]`,可空 |
| `next_action` | string | 下一步建议(给人 / 给调用方) |

**im_attach 默认规则**(各 stage 一致):
- stage1 success: `[{type:"file", path:"<spec.md>"}]`(发新起的 spec)
- stage2 任意: `[]`(stage2 无截图,默认不发附件)
- stage3 verified: `[{type:"image", path:"<main.png>"}]`(只 1 张主截图)
- stage3 verify-failed: ≤4 项(主截图 + ≤2 失败截图 + error-tail.txt)

---

## Spec 头部报告段约定(v2 新)

所有 stage 跑完后**在 spec 头部写报告段**(frontmatter `---` 之后,业务正文 `## 目标` 之前)。每个 stage 一段,**覆盖式写**(每次 stage 跑都重写自己那段,不追加)。

顺序(从上到下):
1. `## Stage 1 report (<today>)` — stage1 起草报告
2. `## Stage 2 report (<today>)` — stage2 实现报告(成功 / 失败)
3. `## Stage 3 report (<today>)` — stage3 verify 报告
4. `## Rework instructions (<today>)` — revise mode 给的返工指令(stage 2 下次必读)
5. `## Review feedback (<today>)` — done mode reject 时回写的 review findings

stage 2 失败时不再追加 `## Attempt N failure`,而是把失败信息写进 `## Stage 2 report` 的 VERDICT/失败原因字段。`attempts` 字段在 frontmatter,`attempts >= 3` 自动 `status: blocked`。

`needs-rework` 状态下,stage 2 必须**先读** `## Rework instructions` 段作为补充约束,再实现。

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
