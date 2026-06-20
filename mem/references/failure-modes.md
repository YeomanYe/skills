# mem 失败模式(Red Flags + Rationalizations)

任一命中 = STOP,不要合理化继续。

---

## Red Flags(STOP 信号)

### RF-1: 召回时 `ls data/<cat>/` 全量 `cat`

**症状**: agent 调 `ls ~/.../mem/data/unblock/` 后逐个 `Read`,炸 token。

**正解**: 先 `Read INDEX.md`,关键词匹配 ≤ 3 条 slug,只 `Read` 这几条。INDEX 优先级**永远高于**目录扫描。

---

### RF-2: 看到死路签名继续原路

**症状**: WebFetch 拿到 302 redirect 到 `accounts.larksuite.com/accounts/page/login` → agent 想"哦没登录,我登录一下" → 继续走 WebFetch 路。

**正解**: 死路签名(302 / 401 / 403 / ECONNREFUSED / utm_source)= 强制进 mem unblock 分类 lookup。不要自我合理化"小问题登录就行"。这正是 unblock 分类的核心使用场景——继承自原 unblock-recipes 的 symptom-triggered 硬规则。

---

### RF-3: 改下游副本

**症状**: agent 在 `~/.claude/skills/_*__mem/` 或 `~/.config/skillshare/skills/_*/mem/` 下面直接 Write / Edit。

**正解**: 中心仓库**单一事实源**是 `~/Documents/projects/skills/mem/`。下游副本是 skillshare 的 sync target,改了等于白改——下次 `skillshare sync --force` 会覆盖。bump hit_count / append access-log 也必须在中心仓库改。

---

### RF-4: agent 自助写 env / unblock

**症状**: agent 没经 exp-sum 分诊,直接在 `data/env/` 或 `data/unblock/` 创建文件。

**正解**: agent 自助写入**只允许写 staging**。写 env / unblock 必须:
- 经 exp-sum 分诊判定路由
- 或用户/orchestrator 显式指定分类

否则一律落 staging,等升格审。

---

### RF-5: 跳过 access-log

**症状**: lookup / write / promote 完成但没 append `data/access-log.jsonl`。

**正解**: access-log 是 hit_count 升格阈值和 TTL 淘汰的统计依据。跳过 = 升格机制失效。每次操作必须 append。

---

### RF-6: 把个人偏好写进 mem

**症状**: "我喜欢用 pnpm" / "我不用 yarn" / "我的 IDE 是 VS Code" 被写进 mem。

**正解**: 个人偏好走 `auto memory`(feedback / user 类)。mem 装的是**工程级跨 agent**事实和经验,不是个人风格。

---

### RF-7: 把项目级规则写进 mem

**症状**: "本项目用 mobx,组件不要直接订阅" 被写进 mem 的 unblock。

**正解**: 项目级规则进项目根 `CLAUDE.md` / `AGENTS.md`。mem 是**跨项目**的——只有"跨 agent / 跨项目复用"的事实和经验才进 mem。

---

### RF-8: 写入含明文密钥 / token

**症状**: "我的 QQ 授权码是 xxxxx" 被写进 mem env(包括 staging)。

**正解**: **任何**含明文密钥 / token / 密码的内容**不进 mem**,只存 `~/Documents/knowledge/local/.env`(权限 600,不进任何 git)。mem env 只记**引用**(叫什么名字 / 怎么读 / 存哪个文件)。

---

### RF-9: 升格建议自动执行

**症状**: mem 在 promote 流程里直接 `mv data/staging/<slug>.md → data/unblock/`,或直接调 flow-skill-dev 孵化新 skill。

**正解**: 升格只给建议,**人/有判断的 agent 拍板执行**。自动执行容易产出字段不全的 unblock entry 或触发不准的新 skill。

---

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "INDEX 不全,我 ls + cat 看看" | INDEX 不全是要补 INDEX,不是绕过它。补 INDEX 是改 mem;ls + cat 是炸 token。 |
| "这次 302 我知道怎么处理,不用查 mem" | 你"知道"的版本可能是错的或过时的。mem 是几次踩坑沉淀的版本,优先信它。 |
| "改 ~/.claude/skills/mem 测试一下,过会儿手动同步" | 99% 会忘。要么改中心仓库 + sync,要么不改。 |
| "这个 entry 看起来像 unblock,我直接写 data/unblock/" | 没经分诊容易字段不全(缺 symptoms / 常见错法 / 正解)。先写 staging,升格时再补齐。 |
| "access-log 不重要,这次先不写" | 一次不写,下次也不写,升格机制就废了。 |
| "我喜欢 pnpm 是工程偏好,算工程级吧" | 偏好就是偏好。"工程偏好" 是个借口,实质还是 per-user 风格。auto memory。 |
| "明文 token 写 staging 没人看就行" | git 是公开的(skills repo 推 GitHub)。任何 staging 都会进 git。明文一旦写就泄露。 |
| "升格条件到了我先执行,用户回头看不爽再回滚" | 回滚成本远高于"等审"。升格只给建议。 |

---

## 触发后恢复路径

| 红线触发 | 恢复 |
|---|---|
| RF-1 已经 cat 全量 | 停下,把已 read 的内容从上下文丢掉,改读 INDEX |
| RF-2 已走死路 | 立刻退回,进 mem unblock lookup |
| RF-3 已改下游 | 把改动手动复制到中心仓库 + commit,下游改动用 sync 覆盖回来 |
| RF-4 已写 env/unblock | 把文件 mv 到 staging,补字段后再升格 |
| RF-5 已跳 access-log | 补 append 一行,ts 标"补登记" |
| RF-6/7 已写错位 | mv 到正确位置(auto memory / CLAUDE.md),mem 这边删 |
| RF-8 已写明文 | **立刻**删 entry + git history 重写(`git filter-repo`),通知用户轮换该 token |
| RF-9 已自动升格 | rollback(`git revert`),重写为建议格式让用户审 |
