# Skill Matching Rules

`director-architect` 在 Research Phase **Step 3** 用本规则集动态匹配本地 best-practice skill，
**禁止把 skill 清单写死在 SKILL.md**。

## 为什么必须动态匹配

- 本地 skill 集合随用户安装持续变化
- 项目栈也千变万化（fresh / preact / deno / next / sveltekit / 自定义...）
- 写死清单要么漏栈（用户装了新 skill 没人引用）要么硬塞（不匹配的 skill 被强行调用）
- 动态匹配 + 显式列"未覆盖的栈" = 既不漏也不强塞

## 扫描目录优先级

按下列顺序扫描，去重后合并：

1. `~/.claude/skills/`
2. `~/.agents/skills/`
3. `~/.config/skillshare/skills/`
4. `~/.cursor/skills/`（若用户在用 Cursor）
5. 当前项目的 `.claude/skills/`、`.agents/skills/`（项目内自定义 skill）

只扫顶层目录名 + `SKILL.md` 的 frontmatter。**不**递归读取整个 SKILL.md 正文（太重）。

## 匹配规则（从高到低优先级）

### 规则 0（tie-break，凌驾所有匹配规则）：frontmatter `name` 是唯一权威身份

skill 的**规范身份 = `SKILL.md` frontmatter 的 `name` 字段**。目录名只是物理落盘位置，
经常带安装来源前缀（`_<author>-...-official`、`_<repo>-...`），**不是 skill 身份**。

- **粗筛**：可以用目录名命中 stack 关键字把 skill 拉进候选池（规则 1 第一种命中方式）。
- **身份 / 去重 / 引用 / 调度 / 最终列表**：一律以 frontmatter `name` 为准。
- **目录名与 `name` 不一致时，永远用 `name`**；目录名只在报告里当"来源路径"附注，不当身份。
- **退化**：仅当 frontmatter 缺失或无 `name` 字段，才用目录名当 name（见末尾"边界情况"表）。

> **Worked example**（路由器最易翻车的场景）：
> 目录 `_vercel-react-best-practices-official/`，但 `SKILL.md` 内 `name: deploy-to-vercel`。
>
> | 步骤 | ❌ 错（按目录名） | ✅ 对（按 frontmatter `name`） |
> |---|---|---|
> | 粗筛入池 | 目录名含 `react`/`vercel` → 入池 ✓ | 同样入池 ✓（粗筛可用目录名） |
> | 身份 | 当成 "vercel-react-best-practices" | 是 `deploy-to-vercel` |
> | 报告列出 | `vercel-react-best-practices (...)` | `deploy-to-vercel (~/.claude/skills/_vercel-react-best-practices-official/) — 结论: …` |
> | 去重 key | 目录名 | `deploy-to-vercel` |
> | 下游派工 | 派给一个不存在的 `vercel-react-best-practices` | 派给 `deploy-to-vercel` |
>
> 同一 `name` 出现在两个不同前缀目录 → 按 `name` 视为**同一 skill**（去重保留扫描顺序最前的），
> 不因目录名不同误算两个。

### 规则 1：skill 目录名 / `name` 字段含 stack 关键字

最高优先级（受规则 0 约束：匹配/粗筛可用目录名，**身份与去重必须回落到 `name`**）。例：

| 识别到的栈 | 关键字 | 命中示例 |
|---|---|---|
| `react` / `next` | `react` / `next` / `vercel-react` | `vercel-react-best-practices` |
| `preact` / `fresh` | `preact` / `fresh` | `developing-preact` |
| `deno` | `deno` | `deno-expert` / `deno-frontend` |
| `vue` / `nuxt` | `vue` / `nuxt` | （按现场） |
| `svelte` / `sveltekit` | `svelte` | （按现场） |
| `tailwindcss` | `tailwind` / `tw` | （按现场） |
| `typescript` | `typescript` / `ts` | （按现场） |
| `go` | `go` / `golang` | （按现场） |
| `rust` | `rust` | （按现场） |
| `python` | `python` / `py` | （按现场） |
| `monorepo` | `monorepo` / `pnpm-workspace` / `nx` / `turbo` | （按现场） |

### 规则 2：`SKILL.md` 的 `description` 含 stack 关键字

次优先级。只读 frontmatter description 行（避免把整个 SKILL.md 拖进上下文）。

例：description 含 "React Server Component" → 匹配 `react` / `next` 栈。

### 规则 3：用户明确点名的 skill

无论是否匹配栈关键字，**直接纳入**评估清单。

例：用户说"也让 `web-design-guidelines` 看看 a11y" → 即使项目栈没 React，也纳入。

### 规则 4：项目规则架构方法本身

由 `director-architect` **自己**承担（不调用任何"project-rules-design"或同名 skill，因为它已被本 skill 吸收）。

## 去重 + 输出

最终产出本次评估的 skill 列表，在 Output Contract 显式列：

```md
### 参与联合评估的 skill 清单
- <skill-name> (<来源绝对路径>) — 结论: <一句话>
- <skill-name> (<来源绝对路径>) — 结论: ...
- **未覆盖的栈**: <list 或 "无">
```

**禁止**：
- 把同一 skill 在不同目录的副本算两次（用 frontmatter `name` 字段去重，**不是目录名**——见规则 0）
- 用 `npx skills` / 网络调用（只读本地目录）
- 凭"我以为有 X skill"凭印象列（必须真的扫到才算）

## 未覆盖栈的处理

某个识别到的栈在所有扫描目录都找不到对应 skill：

- **不**硬套最接近条目（如把 `vue` 的 skill 塞给 `svelte` 栈）
- 在 Output Contract "未覆盖的栈" 显式标注
- 在 research 报告的"风险与权衡"段说明影响（如 "该栈无 best-practice skill，
  本 skill 只能基于 stack-checklist.md 通用条目做评估，深度不够"）
- 建议用户补充对应的 best-practice skill 或手写规则条目

## 边界情况

| 场景 | 处理 |
|---|---|
| 同名 skill 在多目录都有 | 优先级取扫描顺序最前的；其余忽略，但在报告里标注"还有其他副本" |
| skill 没 frontmatter / `name` 字段缺失 | 用目录名当 name |
| skill 目录里没 `SKILL.md` | 跳过，不算可用 skill |
| 用户点名了一个本地不存在的 skill | 报告"用户点名的 X 在本地找不到"，建议安装路径或跳过 |
| 项目有 `.claude/skills/` 但里面是符号链接 | 按链接目标解析；如果链接断裂，跳过并报告 |
