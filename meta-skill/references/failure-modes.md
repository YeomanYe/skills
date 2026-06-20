# Failure Modes — Red Flags / Rationalizations / Common Errors

完整失败清单,SKILL.md 主体只保留高频 trip-wire,详细看这里。

---

## 1. Red Flags — 命中任一立即停下

### 1.1 没 apply 就动文件

- 用户回复模糊("好"/"嗯"/"随便")你判定为同意
- 用户回复部分肯定("听起来对")你跳过 plan 重出直接执行
- 你在出 plan 同一轮就建了 symlink

→ **halt + 撤销已建文件(若有)**。Apply Gate 不可绕过。

### 1.2 自动 hook 触发

- 检测到 cwd 切换就跑本 skill
- exp-sum 上游发"项目阶段切换"信号你接了
- cron / launchd / shell hook 自动触发

→ **halt + 报错**。本 skill 仅响应用户手动触发。砍 stage 之后,不存在"项目阶段切换"这个信号。

### 1.3 改全局

- 改 `~/.config/skillshare/config.yaml`
- 在 `~/.claude/skills/` 母目录删除 / 重命名 / 改文件
- 跑 `skillshare enable <skill>` 或 `skillshare disable <skill>`(本 skill 只用 `skillshare list --json` read-only)

→ **halt**。改全局走 skillshare 用户自己跑,不归本 skill。

### 1.4 输出已砍的字段

- JSON 输出含 `stage` / `stage_confidence`
- 输出含 `disable[]` / `keep[]`
- 输出含 `manifest.json` 路径
- plan 里出现"项目阶段:dev"之类描述

→ **halt + 重写 plan**。本版本砍掉了 stage 概念和 disable/keep 字段。

### 1.5 Sentinel 越界

- 写到 `<!-- meta-skill:begin -->` 之前
- 写到 `<!-- meta-skill:end -->` 之后
- 一个文件出现多组 begin/end
- begin 没配对 end(或反之)

→ **halt + 让用户先手动清理**。本 skill 不自动修复结构异常。

### 1.6 Refresh 非幂等

- 同一项目状态 + 同一全局状态 → 连跑两次 refresh 得到不同结果(symlink 数量不同 / sentinel 段内容不等价)
- sentinel 段每次重算都多出无意义换行 / 空行 / 不稳定排序

→ **bug,需要查实现**。排序必须用稳定 sort(skill name 字典序),时间戳放到 `<!-- meta-skill:meta -->` 段以下。

### 1.7 误处理非 symlink

- `<project>/.claude/skills/X` 已存在但是**实文件**(用户手放的)
- 你 `rm` 它再 `ln -s`,把用户的文件丢了

→ **halt + 报错给用户**,等用户自己决定处理。

### 1.8 prepare.sh 双源漂移

- 在 prepare.sh 里内嵌一份固定 skill 清单(`SKILLS=(director-frontend ...)` 等)
- sentinel 段改了,prepare.sh 里的清单没同步 → 新机器跑出来跟当前 fs 不一致

→ **bug**。prepare.sh **必须**运行时从 `CLAUDE.md` sentinel 段读"项目级补充"列表,
   不内嵌清单。sentinel = 唯一事实源。

### 1.9 prepare.sh 缺标记头

- 写 prepare.sh 时没加 `# meta-skill prepare.sh v<N>` 注释头
- 下次 refresh 没法判断这文件是 meta-skill 生成的还是用户自己写的
- 你按"看着像"判定 → 覆盖了用户文件

→ **必须加版本标记头**。无标记 = 当作用户文件,halt 让用户确认。

---

## 2. Rationalizations to Reject

| # | 你想说 | 真相 |
|---|---|---|
| 1 | "用户上次会话说过 apply,这次默认 apply" | 跨会话不留授权。每次 apply 必须当下显式。 |
| 2 | "改一下 ~/.claude/skills/ 顺手把残留清掉" | 那是 skillshare sync target,改了下次 sync 被覆盖。让用户走 skillshare 处理。 |
| 3 | "stage 推断 70% 准也够用了,加回去" | 本版本明确砍掉 stage。skill 自己 description 处理触发时机。 |
| 4 | "manifest.json 留着方便审计" | sentinel 段就是 manifest;再造一份平行结构 = 维护两套。 |
| 5 | "skillshare CLI 慢,我估算下 globally_active 就行" | 必须真跑 `skillshare list --json` 或 ls fallback;不能脑里估。 |
| 6 | "用户在 sentinel 段手改的看起来没用,直接覆盖" | 不行。手改可能是临时关闭某 skill 的尝试。必须 diff + 问。 |
| 7 | "delta 里有个 skill 不存在于 skillshare,跳过就完了" | 不行。`errors[]` 必须显式记录,plan 里也要列,不能默默吞。 |
| 8 | "项目没 .git,我按 cwd 当根" | 不行。没 git root = 项目边界不明,halt。 |
| 9 | "PowerShell / Windows 不支持 symlink,我改 copy" | 本版本不支持 Windows(symlink 是核心)。明确告诉用户走 WSL 或不支持。 |
| 10 | "已 symlink 但目标变了(skillshare 重组),自动重指" | 不行。算 delta 时把"指错 src 的旧 symlink"当作 `delta_remove`,新建 `delta_add`,走 apply gate。 |
| 11 | "prepare.sh 加点注释让人看着舒服" | 不行。模板必须**字节级一致**(便于 refresh idempotent 判定)。要改改 `references/prepare-sh-template.sh`,统一升 v 号。 |
| 12 | "prepare.sh 把 skill 清单写死可以省一次 awk" | 不行。sentinel 改了脚本不会自动跟进 → 双源漂移。必须 runtime 读 sentinel。 |
| 13 | "新机器没 skillshare CLI,我让 prepare.sh 自己 git clone" | 不行。本版本明确**前提**是新机器装好 skillshare;否则 fail-fast 报错 + 提示用户装,不内嵌 clone fallback。 |

---

## 3. Common Errors — 操作出错怎么办

### 3.1 `ln -s` 报 "File exists"

- 原因:目标已存在(symlink 或实文件)
- 处理:先检查是否是 symlink + 是否指向相同 src;是 → 跳过;不是 → halt 报错让用户处理

### 3.2 `skillshare list --json` 返回空 / 报错

- 可能原因:用户没初始化 skillshare / 路径不对 / CLI 版本太老
- 处理:fallback 到 `ls ~/.claude/skills/`,`fallback_used: "ls"`,`errors[]` 加 warning

### 3.3 跨文件系统 symlink

- macOS / Linux 默认支持
- Windows NTFS 需要 admin / dev mode

→ 本 skill 不解决跨系统,**Windows 用户走 WSL 才支持**。

### 3.4 中心库结构变化(skillshare upgrade)

- 已有 symlink 指 `~/.config/skillshare/skills/old_repo/X`,skillshare upgrade 后变成 `new_repo/X`
- Refresh 时检测到旧 symlink target 不存在 → 列为 `delta_remove`,重新算 `delta_add` 指新 src

→ 自愈机制依赖 refresh,**不自动后台扫**。

### 3.5 monorepo 多层 `.claude/skills/`

- root 有一份 sentinel + .claude/skills/
- subpackage 有一份 sentinel + .claude/skills/
- 子项目的 sentinel 段标 `parent: <root path>` 元数据,避免循环

→ 本 skill 当前**不支持自动级联**,monorepo 各 subpackage 用户分别跑 meta-skill 一次。

### 3.6 用户跨设备同步

- 用户在机器 A apply 后 git push,机器 B git pull
- 机器 B 的 sentinel 段在 CLAUDE.md(已提交)
- 机器 B 的 .claude/skills/(已 gitignore)是空的

→ 机器 B 跑一次 `meta-skill refresh`,根据 sentinel 段已列的项 + 新算 delta,重建 symlink。

---

## 4. Halt Recovery — halt 之后怎么办

每次 halt 必须满足:

- **不留 fs 残留**(没有半 apply 的 symlink / 半改的 .md / 半写的 .gitignore)
- **状态可恢复**(下次重跑 meta-skill 跟 halt 前等价)
- **明确告诉用户为什么 halt**(用 STOP 的具体理由,不是"出错了")

halt 后用户怎么走:

- halt 原因是 user gate 拒绝 → 用户改主意可再说 `apply`,plan 还在对话里
- halt 原因是结构异常(多组 sentinel)→ 用户手动清理后,重跑 meta-skill
- halt 原因是 `.git` 找不到 → 用户 cd 到正确根,重跑
- halt 原因是 skillshare CLI 完全坏 → 用户修复 CLI 或选 ls fallback(在 plan 时建议)

---

## 5. 输出 JSON 时容易漏的字段

| 字段 | 漏的后果 |
|---|---|
| `fallback_used` | 用户不知道是真 CLI 数据还是 ls 推断,可能信任错数据 |
| `errors[]` | 跳过的 skill 没记录,下次 refresh 不知道为啥少 |
| `user_gate_response` | 审计不出来用户当下到底回复了啥 |
| `delta_remove` | refresh 时只列加不列减,忘记 sentinel 里要删的条目 |
| `actions_applied` | 应该跟 `actions_planned` 长度一致;不一致 = 中途出错没记 |
| `prepare_sh_path` | 漏 = 用户不知道脚本写哪里了,新机器复刻流程缺一环 |
| `prepare_sh_status` | 漏 = 不知道是新建 / 刷新 / 跳过 / 被 halt,refresh 审计断了 |

输出契约的字段**不允许省略**,即使是空数组也要显式 `[]`。
