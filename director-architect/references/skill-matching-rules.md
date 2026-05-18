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

### 规则 1：skill 目录名 / `name` 字段含 stack 关键字

最高优先级。例：

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
- 把同一 skill 在不同目录的副本算两次（用 `name` 字段去重）
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
