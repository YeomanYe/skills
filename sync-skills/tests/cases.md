# sync-skills 测试用例

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
请使用 `sync-skills` 将这个 skill 同步到全局 `skillshare` source，并同步到当前环境中已存在的其他研发工具全局 skill 目录。

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

请使用 `sync-skills` 同步这个 skill：
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

请使用 `sync-skills` 同步 `/tmp/not-a-skill`。
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

请使用 `sync-skills` 同步这个 skill：
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

请使用 `sync-skills` 同步一个全局 skill。

要求：
- 同步到中心目录和其他已存在研发工具目录
- 但默认不要同步到 `~/.codex/skills/`
- 因为当前环境下 Codex 已能读取 `~/.agents/skills/`
```

### Expected

- `destination` 数组不包含 `~/.codex/skills/`
- 仍会包含 `~/.config/skillshare/skills/`
- 若已存在 `~/.agents/skills/`、`~/.claude/skills/` 等目录，仍应同步到这些目录

---

## Plugin 前缀剥离 (SN 系列)

这一组针对脚本 `_scripts/sync_skill_to_center.sh` 的 plugin 前缀剥离启发。
用 `live` 模式跑（实际 `bash` 脚本验证 stdout / stderr / 落盘结果），不要纯文本模拟。

> 注：Case 1-5 的 fan-out 描述与当前 SKILL.md（默认不向 AI 工具目录 fan-out）不一致，
> 是历史遗留断层，应在后续单独的 cleanup 任务里处理；本次只在 SN 系列里加新覆盖。

### 共用 Setup（所有 SN case 复用同一个隔离沙箱）

脚本的 plugin 剥离启发检测 `$HOME/.claude/skills/*` 等路径。为避免污染真实
`~/Documents/projects/skills/` 和真实 `~/.claude/skills/`，把 `HOME` 重定向到临时沙箱。

> macOS 注意：`/tmp` 是 `/private/tmp` 的 symlink，脚本内 `pwd -P` 会解析 symlink。
> 必须用 `pwd -P` 把沙箱路径也 canonicalize，否则 glob 匹配不上。

```bash
SCRIPT=~/Documents/projects/skills/sync-skills/_scripts/sync_skill_to_center.sh

RAW_SANDBOX="$(mktemp -d)"
SANDBOX="$(cd "$RAW_SANDBOX" && pwd -P)"
mkdir -p "$SANDBOX/Documents/projects/skills"
mkdir -p "$SANDBOX/.claude/skills"

make_skill_dir() {
  local dir="$1" name="$2"
  mkdir -p "$dir"
  printf -- '---\nname: %s\ndescription: test\n---\n' "$name" > "$dir/SKILL.md"
}
```

所有 case 都在 `HOME="$SANDBOX" NICHE_AUTOSYNC_GIT=0 ...` 前缀下执行。

### SN1 - 普通源目录不剥前缀

#### Setup

```bash
make_skill_dir "$SANDBOX/work/some-skill" some-skill
```

#### Run

```bash
HOME="$SANDBOX" NICHE_AUTOSYNC_GIT=0 bash "$SCRIPT" "$SANDBOX/work/some-skill"
```

### Expected

- stdout 含 `effective_skill_name=some-skill`
- stderr 不含 `stripping plugin prefix`
- `$SANDBOX/Documents/projects/skills/some-skill/SKILL.md` 存在

### SN2 - sync target 自动剥单段 plugin 前缀

#### Setup

```bash
make_skill_dir "$SANDBOX/.claude/skills/_YeomanYe-skills__foo" foo
```

#### Run

```bash
HOME="$SANDBOX" NICHE_AUTOSYNC_GIT=0 bash "$SCRIPT" \
  "$SANDBOX/.claude/skills/_YeomanYe-skills__foo"
```

### Expected

- stderr 含 `stripping plugin prefix '_YeomanYe-skills__foo' → 'foo'`
- stderr 含 `set DEST_NAME=<name> to override`
- stdout 含 `effective_skill_name=foo`
- 落盘到 `$SANDBOX/Documents/projects/skills/foo/`，**不**生成 `_YeomanYe-skills__foo/`

### SN3 - sync target 自动剥带 `skills__` 中段的前缀

#### Setup

```bash
make_skill_dir "$SANDBOX/.claude/skills/_obra-superpowers__skills__bar" bar
```

#### Run

```bash
HOME="$SANDBOX" NICHE_AUTOSYNC_GIT=0 bash "$SCRIPT" \
  "$SANDBOX/.claude/skills/_obra-superpowers__skills__bar"
```

### Expected

- stderr 含 `stripping plugin prefix '_obra-superpowers__skills__bar' → 'bar'`
- stdout 含 `effective_skill_name=bar`
- 落盘到 `$SANDBOX/Documents/projects/skills/bar/`（中段 `skills__` 被正确消化）

### SN4 - `DEST_NAME` 强制 override

#### Setup

```bash
make_skill_dir "$SANDBOX/.claude/skills/_YeomanYe-skills__qux" qux
```

#### Run

```bash
HOME="$SANDBOX" NICHE_AUTOSYNC_GIT=0 DEST_NAME=baz bash "$SCRIPT" \
  "$SANDBOX/.claude/skills/_YeomanYe-skills__qux"
```

### Expected

- stderr **不**含 `stripping plugin prefix`（因为 `DEST_NAME` 已设置，跳过自动逻辑）
- stdout 含 `effective_skill_name=baz`
- 落盘到 `$SANDBOX/Documents/projects/skills/baz/`，**不**生成 `qux/` 或 `_YeomanYe-skills__qux/`

## IM 来源自动提交触发

> 这组验证自动提交的触发条件（本次放宽：飞书 → 任何 IM 会话）。
> 需中心目录是 git 仓库；用例不带 `NICHE_AUTOSYNC_GIT=0`。

### GIT1 - 飞书会话触发自动提交

#### Run
```bash
HOME="$SANDBOX" CC_SESSION_KEY="feishu:abc123" bash "$SCRIPT" "$SANDBOX/work/some-skill"
```

#### Expected
- stdout 含 `git_status=pushed`（或 `committed`，若 sandbox 无 remote）
- commit message 形如 `feat(some-skill): sync from feishu session`

### GIT2 - 其他 IM 会话同样触发（本次改动核心）

#### Run
```bash
HOME="$SANDBOX" CC_SESSION_KEY="telegram:xyz789" bash "$SCRIPT" "$SANDBOX/work/some-skill"
```

#### Expected
- stdout 含 `git_status=pushed`（或 `committed`）——**不再因为非飞书就 skip**
- commit message 形如 `feat(some-skill): sync from telegram session`

### GIT3 - 本地 CLI 会话不触发

> ⚠️ 必须 `env -u CC_SESSION_KEY` 清掉变量。若测试本身在 IM 会话（如飞书）里跑，
> `CC_SESSION_KEY` 会从父进程泄漏给子进程，导致本用例假阴性（误判为 IM 会话）。

#### Run
```bash
env -u CC_SESSION_KEY HOME="$SANDBOX" bash "$SCRIPT" "$SANDBOX/work/some-skill"
```

#### Expected
- stdout 含 `git_status=skipped`
- `git_reason` 含 `non-IM session`（本地 CLI，用户应手动 push）

### GIT4 - NICHE_AUTOSYNC_GIT 覆盖仍生效

#### Run
```bash
# 强制禁用：IM 会话也不提交
HOME="$SANDBOX" CC_SESSION_KEY="feishu:abc" NICHE_AUTOSYNC_GIT=0 bash "$SCRIPT" "$SANDBOX/work/some-skill"
# 强制启用：本地 CLI 也提交
HOME="$SANDBOX" NICHE_AUTOSYNC_GIT=1 bash "$SCRIPT" "$SANDBOX/work/some-skill"
```

#### Expected
- 第一条：`git_status=skipped`，`git_reason` 含 `disabled via NICHE_AUTOSYNC_GIT=0`
- 第二条：`git_status=pushed`/`committed`（强制启用覆盖了"非 IM 不触发"）

### Teardown（所有 SN case 跑完后）

```bash
rm -rf "$RAW_SANDBOX"
```
