# todo-init Test Cases

## Case 1: 标准追加（TODO.md 存在 + 走 todo-driver）

- 前置：`TODO.md` 存在，`docs/spec/` 存在，TODO.md 中已有 1-2 个带 slug 的条目
- 输入：用户说"加个 TODO 支持快捷键设置"
- 预期：
  - 不再追问任何问题（除非 hints / depends_on 有不确定）
  - 生成 slug `keyboard-shortcuts` 或 `shortcut-settings`
  - 追加到 `## Features` 末尾
  - 输出包含 slug、行号、`next_step` 提示等 stage 1 cron 出 spec

## Case 2: TODO.md 不存在

- 前置：cwd 下没有 TODO.md
- 输入：用户说"加个 TODO 主题切换"
- 预期：
  - 不替用户创建 TODO.md
  - 报告 "TODO.md 不存在，请先 touch TODO.md"，stop
  - **不**输出 slug / 行号（什么也没追加）

## Case 3: slug 冲突

- 前置：TODO.md 已有 `- [ ] \`theme-toggle\` 主题切换 ...`
- 输入：用户说"加个 TODO 支持主题切换"，可能再次想用 `theme-toggle`
- 预期：
  - skill 检测到 slug `theme-toggle` 已存在
  - **不**自动改成 `theme-toggle-2`
  - 提示用户冲突 + 建议合法语义后缀（如 `theme-toggle-system`、`theme-color-picker`），让用户确认
  - 用户确认后才追加

## Case 4: 用户手指定不合法 slug

- 输入：用户说"slug 用 ThemeToggle，summary 是 主题切换"
- 预期：
  - 校验 `ThemeToggle` 失败（含大写）
  - 提示用户合法版本 `theme-toggle`
  - 让用户回 yes/no 接受或换一个
  - 用户回 yes → 用 `theme-toggle` 追加；其他 → stop 等用户重发

## Case 5: 带 depends_on（被依赖 slug 存在）

- 前置：TODO.md 有 `- [ ] \`theme-toggle\` ...` 已是 - [ ] 状态
- 输入：用户说"加 style-switch，依赖 theme-toggle"
- 预期：
  - 追加 `- [ ] \`style-switch\` ...`
  - 输出中 `depends_on: ["theme-toggle"]`
  - **不**把 depends_on 写进 TODO.md 那一行（写进 spec frontmatter 是 stage 1 的事）
  - `depends_warn` 为空

## Case 6: 带 depends_on（被依赖 slug 不存在）

- 输入：用户说"加 user-settings，依赖 onboarding-flow"，但 `onboarding-flow` 既不在 TODO.md 也不在 docs/spec/_done/
- 预期：
  - 仍然追加（不阻止）
  - `depends_warn: ["onboarding-flow"]`
  - 输出中提示：被依赖项不存在，stage 2 拾起前请先确认

## Case 7: 带 hints

- 输入：用户说"加 dark-mode，提示用 uiStore 管理，参考 tab-shelf"
- 预期：
  - 追加为 `- [ ] \`dark-mode\` Dark mode — ... (用 uiStore 管理，参考 tab-shelf)`
  - hints 写在 TODO 行末括号内
  - **不**把 hints 写进 depends_on

## Case 8: 模糊回复

- 输入：用户说"加个 TODO 多语言"，AskUserQuestion 问 hints，用户回"随便"
- 预期：
  - 取空值默认（无 hints）
  - 不再追问
  - 正常追加

## Case 9: 中文 summary 生成英文 slug

- 输入：用户说"加个 TODO 收藏夹一键导出 HTML"
- 预期：
  - 生成英文 slug，例如 `bookmark-export-html`
  - **不**用拼音（`shoucangjia-yijian-daochu`）作为后备，除非中文无对应英文术语

## Case 10: 在非项目根调用

- 前置：cwd 是项目某子目录，TODO.md 在项目根
- 输入：用户说"加个 TODO"
- 预期：
  - skill 不向上查找
  - 报告"当前目录没有 TODO.md"，stop
  - **不**自动 cd 到项目根

## Case 11: 已知信息不重复追问（key DX 用例）

- 输入：用户一次性说"加 TODO：slug=theme-toggle，summary=支持深色/浅色/跟随系统三态主题切换，hints=用 uiStore 管理"
- 预期：
  - 0 次 AskUserQuestion 调用（信息齐全）
  - 直接进入 Step 3 校验 slug + Step 4 写入
  - 输出报告

## Case 12: 反例 — 用户在改已有 TODO

- 输入：用户说"把 theme-toggle 的描述改一下，加上'跟随系统'"
- 预期：
  - skill **不**触发（这不是新建 TODO）
  - 由 Edit 工具或外层 agent 处理
  - 若误触发，应在 Step 1 探测到 slug 冲突时进入 Case 3 分支

## Case 13: 反例 — 不走 todo-driver 的项目

- 前置：项目没有 docs/spec/，TODO.md 里所有条目都没 slug
- 输入：用户说"加个 TODO 修复 #42"
- 预期：
  - skill 可以触发，但 Step 1 应识别"DRIVER_INACTIVE"
  - 提示用户"该项目未启用 todo-driver，本 skill 仍可追加但不会被流水线自动处理"
  - 用户确认后才追加
