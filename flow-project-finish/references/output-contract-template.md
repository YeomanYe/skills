# Output Contract Template — flow-project-finish 收尾报告完整模板

> 抽离自 SKILL.md。Step 6 收尾报告的完整 markdown skeleton + Output Contract 的强制顺序在此。
> SKILL.md 主体只保留 5-15 行引用 + 缺失即视为未完成的硬约束。

## Step 6 —— 收尾报告 markdown 模板

完成上述阶段后,产出一份汇总报告,**不要省略任何阶段**(即使该阶段被跳过也要写明跳过原因):

```md
## Project Finish Report

### Step 0 — Project Snapshot
- Project type:
- Frontend stack:
- Already a website:
- Existing landing page:
- **Existing web preview**: <path | none>
- **Deployment config**: <[<file>:<current_target_path>:<primary|secondary>, ...] | [platform-only:<platform>:primary] | none>
- Existing docs:
- Design tokens source:
- Roadmap source:
- Git state:

### Step 1 — Doc Sync
- 设计系统:
- 交互文档:
- PRD:
- 架构文档:
- 未发现的类别:

### Step 2 — README
- 状态: created | updated | unchanged
- 文件: <path>
- 主要变更点:

### Step 3 — Landing Page
- 是否需要:
- 既存落地页分流: refresh | rebuild | skip | n/a
- **既存 preview 处理**: 保留为平行资产 <path> | 无 preview | n/a
- 跳过原因(如适用):
- **3 路 mockup**(v5):
  - mockup-1: <style_name> @ .agent/jobs/landing-mockup-1/  (独立性维度: <列举>)
  - mockup-2: <style_name> @ .agent/jobs/landing-mockup-2/
  - mockup-3: <style_name> @ .agent/jobs/landing-mockup-3/
- **飞书推送**: pushed (6 screenshots) | skipped (non-feishu channel) | failed (<reason>)
- **用户选择**: 用户选 mockup-N (回复: "选 N" @ <ts>) | pending | "都不行 重做" | "方向 N 改 X"
- **3.3 实现模式**: A (frontend-design 重写) | B (直接拷 mockup-N → website/) — 按项目栈智能选
- 落地页代码位置:
- 技术栈:
- **部署目标切换**:
  - 主要配置 <file>: <old path> → <new landing path> | 未检测到部署配置
  - 辅助配置确认: [<file>: 用户确认切换 | 用户保留旧指向 | 等用户决定]
  - **预览公开下线**: yes (preview 代码保留在 <path>) | n/a
  - **平台后台手动事项**: 无 | <list>(需在 <platform> 后台改 publish dir)
- 响应式截图: done | skipped(<reason>)
- 被淘汰 mockup 处理: 保留 .agent/jobs/landing-mockup-{X,Y}/(可清理)

### Step 4 — Delivery Gate
- 状态: all clear | must-fix-routed | re-ran-N-times
- must-fix 摘要(如有):
- should-fix 摘要(如有):
- 视觉证据回流 IM:done | n/a

### Step 5 — Clean Commit
- 状态: committed | skipped(<reason>)
- Commit hash:
- Commit message:
- 是否 push:

### 风险与开放决策
- 风险:
- 用户需要书面确认的事项:
```

## Output Contract —— 强制顺序

最终交付按以下顺序必须包含:

1. Step 0 的项目快照
2. Step 1 的文档同步明细(包括"未发现"项)
3. Step 2 的 README 状态与变更摘要
4. Step 3 的落地页结果或显式跳过原因
5. Step 4 的 delivery-gate 判定与 must-fix 回流记录
6. Step 5 的 clean-commit hash 与 message(或跳过原因)
7. 风险与开放决策清单

**任一缺失即视为未完成**。

## Delivery Check —— 宣称收尾完成前的核对清单

- Step 0 的 10 个字段全部填写(项目类型 / 前端栈 / 是否网站 / 既存落地页 / **既存 web 预览** / **部署配置** / 现存文档 / 设计源 / 路线图源 / git state)
- Step 1 中 4 类文档的状态都有结论(同步过 / 未发现 / 用户决定不补)
- README 真实存在于项目根,且其中的命令能被 `package.json scripts` 验证
- 落地页阶段:跳过则跳过有理由记录,执行则 `huashu-design` 真的返回了 3 套方向、用户确认了选择、`frontend-design` 真实产出了代码
- 落地页技术栈与项目栈一致(或在无栈时用 vite+pnpm+react)
- 落地页内容三段齐全:Outline / Roadmap / Links
- **既存 preview 在收尾后仍原位存在(未被覆盖/删除/重命名),与 landing 平行**
- **若 Step 0 检测到 deployment config 且生成了落地页 → primary 部署配置已改指向 landing 产物;secondary 配置的去向已在收尾报告里明确(用户已确认或挂"等用户决定")**
- **若部署属于平台后台配置(toml 中不可见) → 收尾报告"开放决策"段列出"需在 <platform> 后台改 publish dir"**
- **递交 delivery-gate 时,部署证据 `Deployment switched` 和 `Preview retained at` 已显式带上,且每条 `Deployment switched` 都通过 `git diff -- <file>` self-check 确认文件真的变了**
- **传给 clean-commit 的变更范围已显式列出 Step 3.3.5 改动的部署配置文件(`vercel.json` / `netlify.toml` / pages workflow 等),scope 为 `docs+landing+deploy`(若切了部署)**
- **`delivery-gate` 真的运行过**(不是 "应该运行")且最终判定为 all clear
- **must-fix 全部消化或被回流处理过**,没有跳过项
- **`clean-commit` 真的产出 commit**(或被显式跳过且原因在报告里)
- 收尾报告所有 7 节都存在(Step 0 / Step 1 / README / Landing / Delivery Gate / Clean Commit / 风险与开放决策)
- 没有把下游 skill 的内部文档复制进本 skill 的 voice
