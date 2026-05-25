# Incident Log — flow-codex-goal 历史踩坑案例

> 这个文件记录的是**真实翻过的车**——每条都对应代码里 `修复 P0 #N` / `修复 P1 #N`
> 的注释源头。看这个文件比看抽象规则更能理解为什么 SKILL.md 写得这么"啰嗦"。
>
> **如果你在改 watcher.sh / SKILL.md 想"简化"某条规则**——先来这里查一下，
> 看那条规则是不是某次事故的修复。是 = 简化前必须先确认事故不会复发。

## 索引

| ID | 严重度 | 现象一句话 | 修复位置 |
|---|---|---|---|
| [P0 #1](#p0-1) | 致命 | macOS 没 GNU `timeout`,reviewer 卡死无超时 | `watcher.sh:479` |
| [P0 #2](#p0-2) | 致命 | `env -i` 清空 PATH 后,reviewer 找不到 codex binary | `watcher.sh:478, 705` |
| [P0 #3](#p0-3) | 严重 | YAML reviewer 解析贪婪匹配,2 个 reviewer 被错读成 10 个 | `watcher.sh:388-395` |
| [P0 #4](#p0-4) | 严重 | `done` 分支不写函数,bash `local` runtime error 让 watcher 半夜挂掉 | `watcher.sh:843, 992` |
| [P0 #10](#p0-10) | 严重 | watcher 退出后 `cc-connect send` 是 bot→user 方向,不会唤醒 orchestrator | `watcher.sh:44-` |
| [P1 #7](#p1-7) | 中 | TMUX-YOLO 模式跑完 5 个 phase,milestone 一次没触发 | `watcher.sh:214, 964` |
| [P1 #8](#p1-8) | 中 | watcher exit code 写到磁盘但 orchestrator 行为没映射 | `SKILL.md:951` |

---

## P0 #1 — macOS 没 GNU `timeout`,reviewer 卡死

**修复位置**:`references/watcher.sh:479` (`run_with_timeout` 函数)

**事故现场**:
- watcher 起 reviewer Codex 时用了 `timeout 600 codex exec ...`
- macOS 默认没装 GNU coreutils,`timeout` 命令不存在
- 命令直接报错退出 → watcher 以为 reviewer 跑完了 → 写空 REVIEW.md → verdict=missing → 误判 fail
- 半夜跑的长任务全凉,早上看 logs 才知道

**修复**:
- `run_with_timeout` 函数自动检测,有 GNU `timeout` 就用,没有就降级到 `( cmd & sleep N; kill %1 )` 的 bg+kill 模式
- macOS / Linux / 容器全适配

**规则启示**:**所有"依赖 GNU 工具"的脚本都必须有 BSD 兜底**——`brew install coreutils`
不能假定用户跑过。skill-doctor 的 `bsd-compat` 规则就是为了挡这种事。

---

## P0 #2 — `env -i` 清空 PATH 后 reviewer 找不到 codex

**修复位置**:`references/watcher.sh:478, 705` (`codex_safe_path` 函数)

**事故现场**:
- 为了 reviewer 硬隔离(防止凭据泄漏),启动时用 `env -i` 清空所有环境变量
- 清完 PATH 也没了 → `codex` 命令 not found → reviewer 启动失败
- 给 reviewer 加 `PATH=/usr/bin:/bin` 又怕用户的 codex 装在 `~/.local/bin` 或 `/opt/homebrew/bin`,
  路径不对一样找不到

**修复**:
- `codex_safe_path` 函数:`command -v codex` 取真实路径,提取 `dirname`,加到 `PATH` 里
- 这样既 `env -i` 清了凭据,又保证 codex binary 可见
- 同时保留 `$HOME` / `$LANG` / `$LC_ALL`(否则 codex 启动后中文输出乱码)

**规则启示**:**硬隔离不是"清得越干净越好"**——清完要测一遍"reviewer 自己还能不能站起来"。
完美隔离 ≠ 可用隔离。

---

## P0 #3 — YAML reviewer 解析贪婪匹配,2 个被错读成 10 个

**修复位置**:`references/watcher.sh:388-395`

**事故现场**:
- 旧版 reviewer 解析逻辑:`extra_reviewers:` 段下,`flag && /^[[:space:]]*-/` 抓所有 dash 行
- 但 reviewer 配置里的 `checks:` 子字段也是 dash 数组:
  ```yaml
  extra_reviewers:
    - name: ux-reviewer
      checks:
        - UX
        - 信息层级
  ```
- 贪婪匹配把 `- UX`、`- 信息层级` 也当成 reviewer 名 → 2 个 reviewer 被错读成 10 个
- 10 个伪 reviewer 全部启动 → codex quota 爆 → review 全部 timeout fail

**修复**:
- 新版按 YAML **第一层缩进**识别——只取 `extra_reviewers:` 下直接子级的 dash 行
- 嵌套字段(`checks:` 下的数组项)按缩进过滤掉
- 同时兼容两种 schema(扁平字符串 / 完整对象)

**规则启示**:**用 awk/grep 解析 YAML 是一颗定时炸弹**。能用 `yq` 就用,不行时
缩进+第一层过滤是底线。「能跑」 ≠「正确」。

---

## P0 #4 — bash `local` runtime error 让 watcher 半夜挂掉

**修复位置**:`references/watcher.sh:843`(`handle_done` 函数) + `SKILL.md:951`(Watcher Exit Code 映射表)

**事故现场**:
- watcher 主循环用 `case` 分支处理 STATUS 信号
- `done` 分支里直接写了 `local arbitration_result=...`
- bash 规则:`local` **只能在函数内用**,case 分支不算 → 运行时报错 `local: can only be used in a function`
- watcher 退出码非 0 → 后续 milestone / review / snapshot 全部丢失
- 半夜跑的 8 小时任务凌晨 3 点就挂了,早上看 STATUS.md 还停在 Phase 1

**修复**:
- `done` 分支抽成 `handle_done` 函数
- 函数返回值即 watcher exit code(0=pass→delivery / 3=retry / 4=human-needed / 5=fail)
- 同步在 SKILL.md 加 "Watcher Exit Code → Orchestrator 行为映射" 表(line 951),
  让 orchestrator 端有明确的"看到 exit code N 该做什么"协议

**规则启示**:**bash 长脚本的所有 `local` / `return` 必须在函数内**——shellcheck 能挡,
但要真的在 CI 跑。一次 runtime error 等于整个任务作废。

---

## P0 #10 — watcher 退出后无人唤醒 orchestrator

**修复位置**:`references/watcher.sh:44-`(Orchestrator Wake-up Combo) + `SKILL.md:970`(Wake-up Combo 段)

**事故现场**:
- watcher 跑完想通知 orchestrator "exit code 3,该 auto-retry 了"
- 通过 `cc-connect send` 发消息——但这是 **bot → user** 方向的消息,IM 平台不会反弹回来
  唤醒 orchestrator 自己(orchestrator 没有 inotify 也没有后台 poll 进程)
- 结果:exit code 写到磁盘 `EXIT_CODE.txt`,**没人来读**
- 用户隔天问"咋停了",orchestrator 才发现 watcher 早死了

**修复**:**A + B 双路组合**
- **方案 A(主路)**:watcher 退出前用 `claude --send` 直接给 orchestrator 发消息(走 inbox,
  Claude Code 真能收到),exit code 完整保留。**响应延迟近 0**。
- **方案 B(兜底)**:watcher 启动时注册一个 30 min cc-connect cron,让 orchestrator
  定时检查 `EXIT_CODE.txt`。A 方案失效时(orchestrator 不是 Claude Code / 裸 shell / cron 触发)
  也能在 30 min 内捞到。

**规则启示**:**通信链路必须设计"主路 + 兜底",两路独立失效**。bot → user 看起来能通,
实际是单向阀。"我发了消息就以为对方收到了" = 异步系统的经典误区。

---

## P1 #7 — TMUX-YOLO 跑完 5 phase milestone 没触发

**修复位置**:`references/watcher.sh:214`(`poll_phase_markers` 函数) + `:964`(主循环每 N 秒扫一次)

**事故现场**:
- TMUX-YOLO 模式下 Codex 在 tmux session 里跑
- watcher 只盯 STATUS.md 的 `^MILESTONE:` 行触发 milestone 推送
- 但 TMUX-YOLO 模式下 Codex 按 `# PHASE-N-DONE @ <ts>` marker 在 **tmux buffer**
  里报告进度,**根本不写 STATUS.md MILESTONE 行**
- 结果:18 min 跑完 5 个 phase,watcher 一次 milestone 都没触发,
  orchestrator / 用户全程黑盒,出 bug 时找不到回放点

**修复**:
- 加 `poll_phase_markers` 函数:`tmux capture-pane` 抓 buffer,grep `# PHASE-N-DONE` marker
- 发现新 marker → 转成 STATUS.md MILESTONE 行 → 复用现有 milestone 推送流程
- 主循环每 `MARKER_POLL_INTERVAL` 秒扫一次

**规则启示**:**通知机制要跟着模式走**。CLI-YOLO 写 STATUS.md,TMUX-YOLO 写 tmux buffer,
不能一套监控代码假定所有模式都用同一种信号源。

---

## P1 #8 — watcher exit code 写到磁盘但没行为映射

**修复位置**:`SKILL.md:951`(Watcher Exit Code → Orchestrator 行为映射表)

**事故现场**:
- 修完 P0 #4 watcher 能正确返回 0/3/4/5 不同 exit code 了
- 但 orchestrator 端不知道 "看到 exit code 4 该做什么"
- 有人理解成 "fail 了重启 watcher",有人理解成 "通知用户但继续等",行为不一致
- 不同 orchestrator(Claude / Codex / 裸脚本)甚至执行不同动作 → 长任务出问题没人能复盘

**修复**:
- 在 SKILL.md 加完整映射表(每个 exit code 对应 orchestrator 该做什么 + 该读哪个文件 + 该不该 ping 用户)
- 映射表是 Phase 0 契约的一部分,orchestrator 必须看完才能进 Phase 1

**规则启示**:**协议两端都要写**。watcher 端发 exit code 不算完,orchestrator 端必须有"看到 N 怎么办"
的对应表。半边协议 = 没协议。

---

## 怎么用这个文件

**新增 case**:任何 P0/P1 事故修复后,**必须在这里加一段**。模板:

```markdown
## P<级别> #<编号> — <一句话现象>

**修复位置**:`<file:line>`

**事故现场**:
- (旧逻辑是什么 / 触发条件是什么)
- (失败表现 — 具体到能在 logs / STATUS.md 里看到的字符串)
- (用户影响 — 任务挂了 / quota 烧了 / 数据丢了)

**修复**:
- (新逻辑做了什么)
- (兼容什么场景)

**规则启示**:**(给后来人的一句话原则)**——(展开 1-2 句解释)。
```

**简化某条规则前**:先 `grep "P0 #N\|P1 #N" SKILL.md references/` 看那条规则是不是事故修复。
是 → 简化前必须确认事故不会复发(写在 commit message 里)。

**新人 onboarding**:不用读 1200 行 SKILL.md,先读这个文件 7 个 case,你就会知道为什么
watcher 这么复杂、为什么 reviewer 要硬隔离、为什么协议两端都要写。
