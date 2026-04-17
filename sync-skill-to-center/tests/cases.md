# sync-skill-to-center 测试用例

这些内容用于定义固定测试 case。

- 固定测试 case 放在本目录下
- 每次执行结果放到仓库的 Git 忽略临时目录
- 在本项目中，执行结果目录为 `.tmp/`

---

## Case 1: 默认当前目录多目标同步

### Prompt

```md
请不要修改任何业务代码。

当前工作目录就是一个已完成的 skill 目录，目录内包含 `SKILL.md`。
请使用 `sync-skill-to-center` 将这个 skill 同步到全局 `skillshare` source，并同步到当前环境中已存在的其他研发工具全局 skill 目录。

要求：
- 不要自动执行 `skillshare sync`
- 输出 `source`、`destination`、`overwrote` 和同步结果
- 路径要使用 `${HOME}` 变量形式
- `destination` 必须是数组
```

### Expected

- 默认把当前工作目录当作源目录
- 检查 `SKILL.md`
- 目标路径至少应包含：
  - `~/.config/skillshare/skills/<当前目录名>/`
- 若当前环境中存在 `~/.agents/skills/`、`~/.claude/skills/` 等目录，也应一并同步
- 默认不应把 `~/.codex/skills/` 计入同步目标
- 明确输出是否覆盖
- 输出格式应为：
  - `source=${HOME}/...`
  - `destination=["${HOME}/...", ...]`
  - `overwrote=0|1`
- 明确建议下一步：`skillshare sync`

---

## Case 2: 显式路径优先

### Prompt

```md
请不要修改任何业务代码。

请使用 `sync-skill-to-center` 同步这个 skill：
`/tmp/my-skill`

要求：
- 不要使用当前目录作为源
- 默认覆盖同名目标
- 输出执行结果
- 路径用 `${HOME}` 变量形式
- `destination` 为数组
```

### Expected

- 使用显式路径 `/tmp/my-skill`
- 不应退回当前目录
- 目标路径至少应包含：
  - `~/.config/skillshare/skills/my-skill/`
- 若当前环境中已存在其他研发工具全局 skill 根目录，也应包含对应目标
- 默认不应包含 `~/.codex/skills/`
- 若该目标已存在同名目录，默认覆盖
- 输出格式应为：
  - `source=<path>`
  - `destination=["<path>", ...]`
  - `overwrote=0|1`

---

## Case 3: 缺少 SKILL.md 时失败

### Prompt

```md
请不要修改任何业务代码。

请使用 `sync-skill-to-center` 同步 `/tmp/not-a-skill`。
其中该目录存在，但不包含 `SKILL.md`。

要求：
- 只模拟 skill 判断
- 输出失败原因
```

### Expected

- 命中校验失败：缺少 `SKILL.md`
- 不应继续执行复制
- 应明确指出失败原因和源路径

---

## Case 4: 来自某个工具全局目录的 skill 也应同步到其他工具

### Prompt

```md
请不要修改任何业务代码。

请使用 `sync-skill-to-center` 同步这个 skill：
`${HOME}/.agents/skills/example-skill`

要求：
- 除了同步到 `~/.config/skillshare/skills/`
- 还要把它同步到当前环境里已存在的其他研发工具全局 skill 目录
- 比如已存在 `~/.claude/skills/`、`~/.codex/skills/` 时，也应出现在这些目录中
```

### Expected

- 不因为源目录已经在 `~/.agents/skills/` 下就跳过跨工具同步
- 会探测本机已存在的其他工具 skill 根目录
- `destination` 数组应包含所有实际同步目标
- 缺失的目录不应强行创建

---

## Case 5: 默认排除 `~/.codex/skills/`

### Prompt

```md
请不要修改任何业务代码。

请使用 `sync-skill-to-center` 同步一个全局 skill。

要求：
- 同步到中心目录和其他已存在研发工具目录
- 但默认不要同步到 `~/.codex/skills/`
- 因为当前环境下 Codex 已能读取 `~/.agents/skills/`
```

### Expected

- `destination` 数组不包含 `~/.codex/skills/`
- 仍会包含 `~/.config/skillshare/skills/`
- 若已存在 `~/.agents/skills/`、`~/.claude/skills/` 等目录，仍应同步到这些目录
