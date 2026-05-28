# Mode `revise` — 给已 verify 的 spec 写返工指令

verify 完(stage3 给 `verified` / `verify-failed`)或人审 ready-for-review 觉得要改时,用 panel 模式给 spec 写 **Rework instructions**(返工指令),改 status 为 `needs-rework`,让 stage 2 下次轮转拾起按指令重做。

跟 `adjust` 的区别:`adjust` 改的是**还没起 spec** 的 TODO 行;`revise` 改的是**已起 spec 且已 stage2 实现过**的 spec(给二次/三次实现的指令)。

## Step 1: 解析参数 + 列候选

- `todo-flow revise <slug>` → 直接处理该 slug 的 spec
- `todo-flow revise` → 扫工程列出所有 status ∈ `{ready-for-review, verified, verify-failed}` 的 spec,让用户选

筛选条件:
- spec frontmatter `status` 在 `ready-for-review` / `verified` / `verify-failed` 之中
- 工程根目录 git 仓库且工作树干净(避免误卷入用户改动)

## Step 2: 显示上下文(让用户基于事实写 rework)

agent 输出三段:
1. **spec 头部已有报告**(`## Stage 2 report` / `## Stage 3 report` 段),让用户看上次实现 + 验证结果
2. **本次改动 diff 摘要**(`git diff <default_branch>...todo/<slug> --stat`)
3. **现有验收标准 + Rework instructions(若有上次留的)**

## Step 3: Panel 模式收集 rework 指令

进入对话循环(类似 adjust 模式),让用户给"修订指令"。每条 instruction 应:
- **具体**:指明哪个文件 / 哪段代码 / 哪个验收标准对不上
- **可测**:stage2 跑完能客观对照(避免"实现得不好"这种废话)
- 一行一条,用 `- ` 列表

支持的快捷模板(用户输入数字编号):
1. `测试覆盖不够: <说明>`
2. `实现偏离 spec <X> 段: <说明>`
3. `走查截图显示 <UI 问题>`
4. `引入了 spec 未授权的依赖 <X>`
5. `修改了 spec 范围外文件 <X>`
6. `性能/可用性问题: <说明>`
7. `<自由文本>`

用户说 "退出" / "exit" / "done" → 进 Step 4。

## Step 4: 写 Rework instructions 到 spec 头部

在 spec frontmatter `---` 之后,所有 `## Stage N report` 段之后,第 1 个业务 `##`(目标 / 现状 ...)之前,**插入或覆盖** `## Rework instructions (<today>)` 段:

```md
## Rework instructions (<today>)
> 由 todo-flow revise 收集。stage2 下次拾起本 spec 时**必读**本段作为补充约束,在原 spec 之上做修正。

- <用户指令 1>
- <用户指令 2>
- ...

(本段每次 revise 都覆盖重写;历史指令归档到下文 ## Decisions log)
```

同时:
- frontmatter `status` 改为 `needs-rework`(stage 2 兼容,当 approved 处理但读本段)
- `updated: <today>`
- 不重置 `attempts`(累积计数,防止无限 rework — `attempts >= 3` 自动 blocked)

## Step 5: Commit + push

```bash
cd <worktree if exists, else project root>
git add docs/spec/<slug>.md
git commit -m "chore(todo): revise ${slug} → needs-rework"
git push  # 默认分支或 todo/<slug> branch,看 spec 在哪
```

## 输出

```json
{
  "mode": "revise",
  "slug": "<slug>",
  "previous_status": "verified | verify-failed | ready-for-review",
  "new_status": "needs-rework",
  "instructions_count": <n>,
  "spec_path": "<...>",
  "summary": "✓ revise: <slug> → needs-rework with <n> instructions",
  "im_attach": [],
  "next_action": "stage 2 下次 cron 会拾起 needs-rework,按指令重做"
}
```

## Common failure modes

- **Step 2 显示阶段没读 worktree diff** → 用户基于陈旧 spec 写指令,失真
- **指令写成废话**("做得更好") → agent 必须用 7 条快捷模板引导,拒绝空话
- **status 不是 ready-for-review/verified/verify-failed 却允许 revise** → 必须先 Step 1 校验,否则会把 draft/approved 的 spec 错误标 needs-rework
