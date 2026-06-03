# meta-skill 测试用例

> 用于 skill-behavior-test 回归基线。**本版本砍掉了 stage 探测 + manifest.json,所有用例都按新算法**(delta = recommended − globally_active → symlink + sentinel)。

---

## 正例触发场景

### Case 1 — 用户首次进入项目(React 扩展)

**输入**:
- cwd = `~/Documents/projects/tab-shelf`(React 18 + wxt 扩展项目)
- 用户:"配下这个项目要哪些 skill"
- 假设 globally_active = `{flow-dev-task, experience-summary, hat, unblock-recipes, find-skills, agent-browser}`

**期望**:
- meta-skill 触发
- 探测 `stack=[react, typescript]` `project_type=[frontend, browser-extension]`
- recommended ⊇ `{director-frontend, director-design, frontend-design, cdp-browser-control, flow-ext-publish, ext-preflight, flow-project-bootstrap, flow-project-finish}` + common-fallback
- delta_add = recommended − globally_active(包含 `director-frontend` / `cdp-browser-control` / `flow-ext-publish` 等)
- 输出 plan markdown,**末尾明确写"等你 apply"**
- **不动任何文件**

### Case 2 — 用户回复 "apply" 后执行

**前置**:Case 1 已出 plan

**输入**:用户:"apply"

**期望**:
- 在 `<project>/.claude/skills/` 建 delta_add 中每个 skill 的 symlink
- 同步建 `.codex/skills/` 和 `.agents/skills/`
- CLAUDE.md 写 sentinel 段(包含 begin/end + 全局已可用 + 项目级补充 + meta 元数据)
- AGENTS.md 同步写 sentinel 段
- `.gitignore` 加 `.claude/skills/` `.codex/skills/` `.agents/skills/` 三行
- 输出 JSON `verdict: "applied"`,`actions_applied` 列表长度跟 `actions_planned` 一致

### Case 3 — Refresh 后中心库加了新 skill

**前置**:Case 2 已 apply,后来用户在 skillshare source 加了新 skill `director-pm`,且全局也同步

**输入**:用户:"meta-skill refresh"

**期望**:
- 重新算 delta
- `director-pm` 现在已在 `globally_active`,所以不进 delta_add
- 如果旧 delta 里有 `director-frontend` 现在被装到全局了 → 出现在 `delta_remove`
- plan 给 add/remove 两段
- apply 后 sentinel 段重写(`director-frontend` 从"项目级补充"移到"全局已可用",`director-pm` 进"全局已可用")

### Case 4 — Refresh 但 delta 没变(idempotent)

**前置**:Case 2 已 apply,中心库 / 全局没变

**输入**:用户:"meta-skill refresh"

**期望**:
- 重算 delta,跟当前 sentinel 段对比 = 完全一致
- 输出 `verdict: "refresh-no-change"`
- **不动任何文件**(即使是 sentinel 段也不"刷新" generated_at 时间戳,因为内容等价)

---

## 反例触发场景(不应执行)

### Case 5 — 模糊回复不算 apply

**输入**:Case 1 已出 plan,用户:"好"

**期望**:
- **halt**,不动文件
- 提示用户:"请明确回复 apply / yes / go"

### Case 6 — 用户拒绝

**输入**:Case 1 已出 plan,用户:"不要"或"等等再说"

**期望**:
- **halt**,verdict = `halted-by-gate`,`user_gate_response: "refused"`
- 不动文件

### Case 7 — 自动 hook 触发(应拒绝)

**输入**:某 shell hook / cron 在 cwd 切换时尝试调 meta-skill

**期望**:
- meta-skill 拒绝执行
- 输出 `verdict: "halted-by-error"`,`errors[]` 含 `"auto-trigger not allowed; meta-skill is manual-only"`

### Case 8 — 用户问 read-only 信息

**输入**:用户:"全局有哪些 skill 可用?"

**期望**:
- meta-skill **不触发**(这是 read-only 询问,应该让 agent 直接跑 `skillshare list` 或用 find-skills)
- 如果触发了 → 应该立刻判 NOT use 然后退出

---

## 边界 / 护栏场景

### Case 9 — 项目没 .git

**输入**:cwd 在 `/tmp/scratch`(无 git)

**期望**:
- halt + 报错 "没找到 .git,请 cd 到正确项目根"
- 不出 plan

### Case 10 — `.claude/skills/X` 已是实文件

**前置**:用户手动放了 `<project>/.claude/skills/X`(不是 symlink),内容是别的东西

**输入**:meta-skill 计算 delta 含 X,准备 symlink

**期望**:
- apply 中途遇到该 X → halt + 报错 "非 symlink 文件已存在,请先处理"
- **不覆盖**用户文件
- 已建的其他 symlink 不撤(部分成功)?→ **不,要全部 rollback**(idempotent 原则)

### Case 11 — skillshare CLI 不可用

**输入**:`which skillshare` 失败 / `skillshare list --json` 报错

**期望**:
- fallback 到 `ls ~/.claude/skills/` 推断 globally_active
- `fallback_used: "ls"`
- `errors[]` 加 warning "skillshare CLI unavailable, used ls fallback"
- 流程继续(不 halt)

### Case 12 — sentinel 段已有用户手改

**前置**:Case 2 已 apply,用户后来在 begin/end 之间手改了某条 skill 说明

**输入**:用户:"meta-skill refresh"

**期望**:
- 检测到 sentinel 段与上次 meta-skill 写的不等价
- diff 给用户看(显示用户改了什么)
- 问:"重算会覆盖你的手改,确认?"
- 用户没明确同意 → halt
- 用户 apply → 覆盖

### Case 13 — 一个文件有多组 sentinel

**输入**:CLAUDE.md 里有两组 `<!-- meta-skill:begin --> ... <!-- meta-skill:end -->`(用户复制粘贴出错)

**期望**:
- halt + 报错 "多组 sentinel 段,请先清理只保留一组"
- 不试图自动修复

### Case 14 — Monorepo

**输入**:cwd 在 `~/Documents/projects/mono/apps/web`,root 是 `~/Documents/projects/mono`(有 `pnpm-workspace.yaml`)

**期望**:
- 检测到 monorepo
- 询问用户:"为整个 monorepo 配,还是为 apps/web 配?"
- 用户选择后继续(不静默假设)

---

## 输出契约 schema 检查

### Case 15 — 所有字段必须存在

每个完成的 meta-skill 输出 JSON 必须含:

```
verdict / must_fix / should_fix / evidence_paths / artifact_path /
project_root / detected_stack / detected_project_type / recommended /
globally_active / delta_add / delta_remove / actions_planned /
actions_applied / user_gate_response / skillshare_cli_available /
fallback_used / errors
```

**漏字段 = 测试不过**,即使是 `[]` 也要显式写。

### Case 16 — 砍掉的字段不能出现

输出 JSON / plan markdown / sentinel 段 **都不能**含:

- `stage` / `stage_confidence`
- `disable` / `keep`
- `manifest.json` 路径(本版本无 manifest 文件)
- "项目阶段:..." 字样

出现 = 实现 bug,测试不过。

---

## 幂等性回归

### Case 17 — 连跑 3 次 refresh

**前置**:Case 2 已 apply

**输入**:连续 3 次 `meta-skill refresh`(项目 + 全局状态不变)

**期望**:
- 第 1 次 → `verdict: "refresh-no-change"`
- 第 2 次 → 同上
- 第 3 次 → 同上
- 整个过程 fs 无任何变化(`ls -la .claude/skills/` 输出 3 次完全一致,包括 mtime)
- sentinel 段内容字符级相同(若实现真覆盖了,至少要保证内容字符级等价)
