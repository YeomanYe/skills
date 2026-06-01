# unblock-recipes Test Cases

按场景分组: 触发 / 写入路径 / 召回路径 / 护栏 / 优先级。

---

## Trigger Tests

### Case 1: 正例触发 — 自动关键词

- 输入: agent 在 flow-dev-task 跑 stage5 时输出"我已经试了 3 次,每次都同样的错"
- 预期:
  - 上游 orchestrator(flow-dev-task)检测到"试了 N 次"关键词
  - 主动调 unblock-recipes lookup
  - 不需要用户显式触发

### Case 2: 正例触发 — 显式查阅

- 输入: 用户说"这个 codex exec 报 ECONNREFUSED 之前踩过吗,查下错题本"
- 预期:
  - mode 解析为 lookup
  - 读 INDEX.md → 匹配 "ECONNREFUSED" / "codex exec" 关键词
  - 若 INDEX 为空 → 输出"匹配 0 条,建议常规调试 + 解决后通过 experience-summary 入册"

### Case 3: 反例触发 — agent 在做新功能不该召回

- 输入: 用户说"实现一下登录页面"
- 预期:
  - mode 解析进 flow-dev-task(实现新功能,非卡壳)
  - **不**主动召 unblock-recipes(预防性翻错题本浪费 token)
  - 只在 stage 中真出现卡壳信号才召

### Case 4: 反例触发 — 用户问的不是错题

- 输入: 用户说"todo-flow 有几个模式"
- 预期:
  - mode 解析为查询(对 todo-flow skill)
  - 不召 unblock-recipes(没有卡壳信号)

### Case 16: 正例触发 — 症状信号 / 选工具前 lookup(本次漏召回回归)

- 输入: agent 要处理 `project.larksuite.com` 的页面,准备开浏览器;工具输出重定向到 `www.meegle.com/?utm_source=in_meegle`
- 预期:
  - **进外部/鉴权系统**(`*.larksuite.com`)即触发:在选浏览器/WebFetch **之前**先读 INDEX.md
  - 即便已经开了浏览器,看到"重定向到营销页/登录页"这个**死路签名**也必须当 blocked 信号,立刻 lookup,而**不是**合理化成"没登录而已,登录就行"继续原路
  - INDEX 命中 `lark-project-url-needs-meegle-cli` → 改用 meegle CLI
  - 反模式(Red Flags 命中): 先选浏览器→撞重定向→才想起查;把重定向当流程正常一步

### Case 17: 反例触发 — 不在每个分支查

- 输入: agent 在正常写代码,函数里有多个 `if` 分支判断,无任何失败/异常/外部系统信号
- 预期:
  - **不**在每个分支/决策点触发 lookup(symptom-triggered 不是 branch-triggered)
  - 只有出现症状(动作失败 / 输出异常 / 进外部鉴权系统)才查
  - 验证硬规则第 1 条不被误读成"处处查"

---

## Writing Path Tests

### Case 5: 主流程写入 — 经 experience-summary 路由

- 前置: agent 刚解决了一个新坑(codex 用 sudo apt-get 后 sandbox 拒绝)
- 输入: 用户调 `experience-summary` 说"刚才那个 sudo apt 在 codex sandbox 里拒绝的坑想记下来"
- 预期:
  - experience-summary Step 1 锁定经验
  - Q9 判定: 跨 agent 通用(任何在 codex sandbox 里跑 sudo apt 的 agent 都会撞) + 卡壳-解法模式 → 路由 unblock-recipes
  - Step 3 输出 recipe 写作模板(填好 frontmatter + 4 段)
  - 用户/agent 把模板落盘到 `unblock-recipes/recipes/codex-sandbox-sudo-apt-blocked.md`
  - 同步更新 INDEX.md 两处(tag `codex` + `sandbox/permission`,symptom `sudo apt` / `sandbox denied`)
  - commit 到中心 + pre-commit hook 跑 skill-doctor 0 ERROR

### Case 6: 拒绝直接写入 — 绕过 experience-summary

- 输入: 用户说"直接给我加个 recipe: sudo apt 在 codex 里不行"
- 预期:
  - 本 skill **拒绝**直接接受写入(SKILL.md "When NOT to Use" + Red Flags 明示)
  - 提示用户: "本 skill 写入入口唯一是 experience-summary 分诊路由,请先调 experience-summary"
  - 不落盘任何文件

### Case 7: 写入护栏 — 不完整 recipe

- 输入: experience-summary 输出的模板被用户填得不全(缺 symptoms 字段或正文 4 段中任一)
- 预期:
  - pre-commit hook 跑 skill-doctor 检测 → ERROR(frontmatter 缺字段 / file-size 0)
  - commit 被阻断
  - 用户回去补全 + 再 commit

---

## Lookup Path Tests

### Case 8: 召回 — 命中

- 前置: recipes/ 已有 `codex-sandbox-sudo-apt-blocked.md`,INDEX.md 列了 symptom "sudo apt" / "sandbox denied"
- 输入: agent 报"试了 3 次 sudo apt install,每次都 sandbox denied"
- 预期:
  - 读 INDEX.md(轻)
  - 匹配 "sandbox denied" → 找到 `codex-sandbox-sudo-apt-blocked` slug
  - 载入 recipes/codex-sandbox-sudo-apt-blocked.md(详)
  - 读"症状信号"段确认真命中
  - 输出"正确做法"段(如:"用 codex_run --network=enabled 或在 sandbox 外预装")
  - 更新 `last_hit: <today>` + `hit_count: N+1`
  - 报告中含"命中 1 条 / 解决 / hit_count 1→2"

### Case 9: 召回 — 未命中

- 前置: recipes/ 有 5 条,无任何 ECONNREFUSED 相关
- 输入: agent 报"playwright 连 9222 端口 ECONNREFUSED"
- 预期:
  - 读 INDEX.md → 找 "ECONNREFUSED" / "9222" / "playwright" → 0 命中
  - 输出"匹配 0 条;建议常规调试;解决后考虑 experience-summary 入册"
  - **不**载入任何 recipe(避免无效 token)

### Case 10: 召回护栏 — 禁止全量载入

- 输入: agent 卡壳后想"看看所有 recipe 找灵感"
- 预期:
  - 本 skill 流程**强制**先读 INDEX.md
  - 不允许 `cat recipes/*.md`
  - 不允许 `ls recipes/` 后挨个 cat
  - 若 INDEX 没匹配 → 直接给"未命中"结论,不允许"翻底"

### Case 11: 召回 — 看似命中实际不是

- 前置: recipe `codex-sandbox-sudo-apt-blocked` symptoms 含 "permission denied"
- 输入: agent 报"git commit 时 hook 拒绝: permission denied"
- 预期:
  - INDEX 匹配 "permission denied" → 候选 recipe `codex-sandbox-sudo-apt-blocked`
  - 载入 recipe 读"症状信号"段
  - 发现实际是 git hook 问题,不是 codex sandbox
  - **不更新** hit_count(避免污染统计)
  - 输出"看似命中实际不是,建议常规调试"

---

## Priority Tests

### Case 12: unblock-recipes 优先于 memory

- 前置: memory 里有"用户 A 偏好在卡壳时优先看 ~/notes/"; unblock-recipes 里有相关 recipe
- 输入: agent 卡壳
- 预期:
  - **先**查 unblock-recipes(通用工程级)
  - 命中 → 应用,不查 memory
  - 未命中 → 才查 memory
  - 召回顺序在 lookup 报告里明示

### Case 13: experience-summary 分诊优先级体现

- 输入: 用户说"我学到的:撒错代码改 typescript 类型时,要 noEmit 不然太慢"
- 预期:
  - experience-summary Q9 判定:
    - 跨 agent 通用?是(任何 agent 写 ts 都受益)→ unblock-recipes 候选
    - per-user 偏好?不是
  - 路由到 unblock-recipes(优先)而非 memory

---

## 维护测试

### Case 14: skill-doctor 通过

- 输入: `node ~/Documents/projects/node-scripts/dist/skill-doctor/index.js --root ~/Documents/projects/skills`
- 预期:
  - unblock-recipes 0 ERROR
  - description < 1000 字符
  - 无 dead-refs / readme-index drift

### Case 15: pre-commit hook 拦截不合规 recipe

- 输入: 用户手写一个不完整 recipe(缺 symptoms 字段)直接 git add + commit
- 预期:
  - pre-commit hook 跑 skill-doctor
  - 若 ERROR > 0 → 阻断 commit
  - 用户补全 frontmatter 再 commit
