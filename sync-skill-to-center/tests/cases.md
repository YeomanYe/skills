# sync-skill-to-center 测试用例

这些内容用于定义固定测试 case。

- 固定测试 case 放在本目录下
- 每次执行结果放到仓库的 Git 忽略临时目录
- 在本项目中，执行结果目录为 `.tmp/`

---

## Case 1: 默认当前目录同步

### Prompt

```md
请不要修改任何业务代码。

当前工作目录就是一个已完成的 skill 目录，目录内包含 `SKILL.md`。
请使用 `sync-skill-to-center` 将这个 skill 同步到全局 `skillshare` source。

要求：
- 不要自动执行 `skillshare sync`
- 输出 `source`、`destination`、`overwrote` 和同步结果
- 路径要使用 `${HOME}` 变量形式
- `destination` 必须是数组
```

### Expected

- 默认把当前工作目录当作源目录
- 检查 `SKILL.md`
- 目标路径为：
  - `~/.config/skillshare/skills/<当前目录名>/`
- 明确输出是否覆盖
- 输出格式应为：
  - `source=${HOME}/...`
  - `destination=["${HOME}/..."]`
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
- 目标路径应为：
  - `~/.config/skillshare/skills/my-skill/`
- 若该目标已存在同名目录，默认覆盖
- 输出格式应为：
  - `source=<path>`
  - `destination=["<path>"]`
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
