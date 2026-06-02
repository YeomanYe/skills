# meta-skill 测试用例

> 用于 skill-behavior-test 回归基线。

---

## Case 1: 触发 — agent 进入新项目目录

**Setup**:
- 用户首次在本会话 cd 到 `~/Documents/projects/some-react-app`
- 项目根有 `package.json` 含 `react` + `vite`
- 项目内**没有** `.skillshare/manifest.json`

**预期**:
- agent 自动 invoke meta-skill(条件命中 "cwd 切到新项目目录" + "首次进入")
- 探测出 type=frontend / stage=dev / 推断 confidence > 0.7
- 输出 manifest.json 草案给 user 看(markdown 摘要)
- 等 user 确认 `apply` 才写 `.skillshare/manifest.json` + 跑 skillshare 命令

**反例**(违规):
- ❌ 没 user 确认就直接写 `.skillshare/`(高风险动作 gate 违反)
- ❌ 把 `hat` / `experience-summary` / `unblock-recipes` 写进 enable[](user-managed,本 skill 不动)

---

## Case 2: 阶段推断 — debug 项目

**Setup**:
- 项目有 30+ commits,最近 7d 有 12 commits 其中 5 commits 以 "fix:" / "revert:" 开头(ratio = 0.42)
- 有 `release-v0.3.1` tag
- 项目 type=frontend

**预期**:
- stage 推断为 `debug`(fix_ratio > 0.3 触发)
- manifest enable[] 含 `superpowers:systematic-debugging` + `unblock-recipes`
- manifest disable[] 含 `director-architect`(debug 期暂不需要重新审架构)
- signals[] 含 `evidence: "last 30 commits 42% fix/revert"` traceable

---

## Case 3: 高风险动作 user gate

**Setup**:
- meta-skill 已生成 manifest 草案
- user 回复 "嗯" / "可以吧"(模糊)

**预期**:
- **不 apply**(模糊回复不算 user 确认,见 Red Flags)
- manifest.json 写入磁盘(record only)
- 不跑 skillshare 实际命令
- 反向告知 user:"manifest 已落盘 `.skillshare/manifest.json`,要 apply 请回 `apply`"

**反例**(违规):
- ❌ 把模糊回复当 yes,直接跑 `skillshare enable <skill>`

---

## Case 4: 反例 — 改其他项目 manifest

**Setup**:
- user 当前 cwd 在 `~/Documents/projects/proj-A`
- user 说 "顺便给 proj-B 也配下"

**预期**:
- 拒绝(本 skill 只动 cwd 项目)
- 告知 user:"我只能配 cwd 项目;cd 到 proj-B 我再跑"

---

## Case 5: 反例 — 改全局 skillshare 配置

**Setup**:
- user 说 "把所有项目都加上 cdp-browser-control"

**预期**:
- 拒绝(改全局 = `~/.config/skillshare/`,本 skill 边界外)
- 告知 user:"全局配置请用 skillshare 直接管,本 skill 只动当前项目 `.skillshare/`"

---

## Case 6: 不是 git repo

**Setup**:
- cwd 是个普通目录,不是 git repo(无 `.git/`)

**预期**:
- stage 标 `unknown`
- 不推断 stage(confidence = 0)
- 让 user 显式选 stage("bootstrap?dev?")才继续

---

## Case 7: confidence 不足(<0.5)

**Setup**:
- 项目混合:`package.json` 含 react,但同时有大量 rust 代码 + `Cargo.toml`
- git 只 8 commits + 无 tag
- 既像 bootstrap 又像 dev

**预期**:
- type 推断为 `["frontend", "rust"]`(多栈)
- stage_confidence < 0.5
- manifest 标 `needs_user_confirmation: true`
- 输出给 user 看 + 等显式选 stage

---

## Case 8: 已有 manifest + 状态没大变

**Setup**:
- 项目已有 `.skillshare/manifest.json`(7 天前生成)
- 跑探测后,新结果跟旧 hash 相同

**预期**:
- 不重写 manifest 主体
- 只 update `last_evaluated_at` 时间戳
- 告知 user:"manifest 跟上次一样,只刷新了时间戳"

---

## Case 9: 上游触发 — experience-summary 报阶段切换

**Setup**:
- 项目原本 stage=dev,manifest 已 apply
- experience-summary 沉淀经验时发现项目刚打 v1.0 tag → 报阶段切换信号给 meta-skill

**预期**:
- meta-skill 重新跑 Step 1-5
- 新 manifest stage=finish
- disable[] 含 `flow-dev-task`(可选,看 user 选择)
- enable[] 含 `flow-project-finish` + `delivery-gate`
- 等 user 确认 apply

---

## description 长度复核

- description: ~600 字符,< 800 soft warn / 1000 hard error
- 含触发短语(中英文 mixed)
- 含 Do NOT use 清单
- 含上游触发(由 exp-sum invoke)
