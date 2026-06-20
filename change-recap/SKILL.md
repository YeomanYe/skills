---
name: change-recap
description: >
  [callable-only · 由 flow-dev-task 编排调用] 改完代码后用 3 段 markdown 出用户视角讲解(哪些场景会出问题 + 改了什么),不写 file:line、不用技术 jargon。
  本 skill **不自主触发**——只在 flow-dev-task 流程内被调用,或用户显式点名("用 change-recap")时使用。**不要根据场景关键词自动触发。**
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# change-recap —— 改动后用户视角讲解

## Overview

**核心心智:同传**。开发者改完代码、agent 解完冲突、按 review 改完——但用户(终端用户 / PM / QA)看不懂技术 commit / git diff。
本 skill 把改动**翻译成用户视角**:**症状场景 + 根因(口语化) + 现在的行为**。

**为什么独立成 skill 而不是 clean-commit 内嵌**:
- clean-commit 是单体职责(挑文件 + 写 message + commit),**不该越界**调讲解
- 编排由 `flow-dev-task` Stage 8 pre-hook 负责;clean-commit 保持纯净
- 用户也可显式调本 skill 单独跑(不走 flow-dev-task)

**3 类适用场景**:
1. **bugfix**:刚修了一个 bug
2. **merge-conflict-resolve**:刚解了一个冲突
3. **accept-review-feedback**:按 reviewer / delivery-gate must-fix 改完

**不适用**:新加 feature(那是 release notes)、纯 UI 调整(那是 director-design + 截图)、代码解读(那是教学)。

## When to Use

### 显式触发(用户主动调)

| 用户原话 | 触发 |
|---|---|
| "讲一下刚改了啥" / "用户视角讲讲" / "解释下这次修复" | ✓ |
| "recap 这次改动" / "change-recap" | ✓ |
| "用户能看到啥变化" / "user-facing recap" / "explain the fix" | ✓ |

### 自动激活(flow-dev-task 编排调)

`flow-dev-task` Stage 8 commit 前若 `task_type ∈ {bugfix, merge-resolve, accept-review-feedback}` 且 `--auto-recap=true`(默认 true)→ 自动调本 skill。

详见 `flow-dev-task` SKILL.md "Stage 8 pre-hook" 段。

## When NOT to Use

- **解读"为啥这段代码这样写"**(代码 walkthrough)→ 普通解释 / `教` hat,不是 change-recap
- **纯 UI 改动**(只动 .tsx/.vue/.css 视觉部分,无逻辑变化)→ `director-design` + 截图更直观;本 skill 可补文字但不主
- **新加 feature**(非 bugfix/merge/review)→ CHANGELOG / user-facing-changelog;本 skill 聚焦"修复型"改动
- **commit message 本身**(技术导向)→ clean-commit 写,不是本 skill
- **全局产品讲解 / release notes**(跨多个改动)→ 项目 README / 落地页,不是 per-change recap
- **改动还没发生**(还在 plan / spec 阶段)→ 等改完再调

## 受众可配(`--audience end-user|pm|dev`)

| 受众 | 默认 | 语气 / 字典 |
|---|---|---|
| **end-user** | ★ 默认 | 全去技术,用业务术语("登录" / "支付" / "搜索"等),不许出现框架名 / 变量名 |
| **pm** | | 可含一点业务模块名 + 影响范围,仍口语化;避免代码细节 |
| **dev** | | 允许提到模块名 + 行为变化(如"timer 触发时机改了"),仍不写 file:line |

CLI 用 `--audience pm` 或 `--audience dev` 切换。flow-dev-task 编排调时透传。

## Workflow

### Step 1: 收集输入

必读:
- `git diff <base>...HEAD --stat`(改了多少 / 改了哪几类文件)
- `git diff <base>...HEAD`(具体改了啥)
- 当前分支名 + 最近 1-3 个 commit message(若已 commit)

可选(handoff 给的或现场拿):
- spec 路径(`docs/spec/<slug>.md` 若存在)
- agent 自报"我刚做了 X"(若是 agent 解完冲突 / 改完代码的同一会话)
- task_type 字段(bugfix / merge-resolve / accept-review-feedback)
- audience(end-user / pm / dev)

### Step 2: 非 UI 边界探测

```bash
git diff <base>...HEAD --name-only | grep -E '\.(tsx|jsx|vue|svelte|css|scss|less|module\.css|html)$' | head -5
```

- **全是 UI 文件 + 仅视觉调整(无 .ts/.js/.py 等逻辑改)** → 输出降级提示:
  ```
  ⚠ 本次改动以 UI 文件为主。建议改用 `director-design` + 截图讲解更直观。
  本 skill 可补文字版,但截图是首选。是否继续?
  ```
  用户回"继续"才进 Step 3;否则退出建议改 director-design
- **逻辑文件占主 / 混合** → 正常进 Step 3

### Step 3: 生成 3 段讲解

按 audience 选语气 + 字典,产出 markdown 3 段。**task_type 不同时,3 段语义稍有侧重**:

#### bugfix 示例(end-user)

```md
## 症状场景
在购物车结算时偶尔会卡 3-5 秒。
## 根因
两个步骤抢同一个资源,谁先到谁等。
## 现在的行为
下单结算 1 秒内完成,不再卡顿。
```

#### merge-resolve 示例(end-user)

```md
## 症状场景
两个分支同时改了登录页(一边加"记住我",一边改了样式),需要合到一起。
## 根因
两边动了同一段代码,要决定怎么共存。
## 现在的行为
"记住我"勾选框保留 + 新样式生效,两边的改动都没丢。
```

#### accept-review-feedback 示例(end-user)

```md
## 症状场景
上一版改完后审核发现 3 个问题:导出文件少一列、错误提示不友好、空状态没图。
## 根因
之前实现时漏了边缘场景,review 指了出来。
## 现在的行为
导出含全部列、错误提示给出修复建议、空状态显示引导图。
```

#### 字段说明(适用所有 task_type)

- **症状场景**: 1-3 行,用户做什么操作时遇到的问题(bugfix)/ 两边分支冲突的业务场景(merge-resolve)/ reviewer 提的具体问题(accept-review-feedback)
- **根因**: 1-2 行,**不写 file:line / 变量名 / 框架名**,用业务术语
- **现在的行为**: 1-3 行,改后用户做同样操作会看到什么

**audience 切语气**:
- end-user → 上面 3 例,全去技术
- pm → 可含业务模块名("结算流程" / "登录页" / "导出功能"),仍口语化,无 file:line
- dev → 允许"行为变化 + 模块名"("checkout endpoint 改无锁队列" 但**仍不**写 file:line)

### Step 4: 长度自检(硬约束)

- **总字符数 ≤ 200**(不含 markdown 标记 / 段标题)
- **三段各 1-3 行**
- **end-user 受众**:扫一遍输出,有以下任一即重写:
  - 出现 `\.(ts|tsx|js|jsx|vue|py|rs|go)` 等扩展名
  - 出现框架名(React / Vue / FastAPI / Django / Tauri / Next / Svelte / Solid 等)
  - 出现 **API / Hook 名**(useEffect / useState / useMemo / Promise / async / await / fetch / axios / useQuery 等高频名词)
  - 出现技术 jargon(stale closure / race condition / debounce / memoization / mutex / hoisting / event loop / hydration / SSR 等)
  - 出现 file:line(如 `Foo.tsx:123`)
  - 出现 **任何代码标识符**(驼峰 `userId` / `handleClick` / 蛇形 `user_id` / 含括号 `foo()` 都判 fail)
- **pm 受众**:允许业务模块名(如"结算"/"搜索"),仍不许 file:line 或代码细节
- **dev 受众**:允许模块名 + 行为描述,仍不许 file:line

自检失败 → 当场重写,**不允许**输出"建议你自己理解一下"这种偷懒。

### Step 5: 输出

按调用方式分发:

- **用户显式调** → 在对话中输出 3 段 + 末尾告知行 `[change-recap audience=<X>]`
- **flow-dev-task 编排调** → 把 3 段 markdown 返回给 flow-dev-task,后者决定:
  - 推 IM(若 `CC_SESSION_KEY` 非空)
  - 拼到 commit message body(若 commit message 总长 < 800)
  - 写到 spec 头部(若 spec 存在)

**IM 推送**(自走 cc-connect,仅 flow-dev-task 编排调时;显式调由用户自己决定):
- 用 `cc-connect send --message "<3段 markdown>"`
- **失败语义按调用方式区分**(对齐 flow-dev-task Fallback):
  - **显式调**(用户主动)→ stop 报警,告知用户("recap 已生成但 IM 推送失败,请检查 cc-connect"),不重试
  - **编排调**(flow-dev-task Stage 7.5)→ **不阻断**主流程(不让 commit 卡在 IM),把失败原因塞 Output JSON `im_pushed: "failed (<reason>)"` 让 flow-dev-task 写进 Final Report `errors[]`
  - 两种情况都**不重试**(防 IM 配置问题死循环)

## Output Contract

```json
{
  "skill": "change-recap",
  "audience": "end-user | pm | dev",
  "task_type": "bugfix | merge-resolve | accept-review-feedback | other",
  "is_ui_change": true | false,
  "ui_warning_shown": true | false,
  "recap_markdown": "## 症状场景\\n...\\n\\n## 根因\\n...\\n\\n## 现在的行为\\n...",
  "char_count": <int,不含 markdown 标记>,
  "self_check": {
    "no_file_line": true,
    "no_framework_name": true,
    "no_tech_jargon": true,
    "within_length": true
  },
  "im_pushed": true | false | "skipped (no CC_SESSION_KEY)",
  "next_action": "<下一步建议>"
}
```

## Red Flags — STOP

- **不收集 git diff 就开始写讲解**(凭脑补 = 编故事 / 描述错改动)
- **改动是新加 feature 却仍调本 skill**(应改用 CHANGELOG;本 skill 只对 3 类修复型)
- **end-user 受众输出含 file:line / 框架名 / 变量名**(违反硬约束)
- **dev 受众输出含 file:line**(dev 也不该看 file:line,他能自己 git diff)
- **改写代码 / 提议改实现**(本 skill 只解读,不改代码)
- **总字符数 > 200**(超长 = 没翻译到位)
- **三段缺一段**(症状 / 根因 / 现在的行为是契约骨架)
- **flow-dev-task 编排调时 IM 推失败仍宣告完成**(失败 stop,不静默)
- **替代 commit message 写技术总结**(commit 是 commit,recap 是 recap,职责分开)
- **UI 改动不提示用 director-design**(违反非 UI 边界)

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户应该看懂技术术语" | 受众是 end-user/pm 时**就是不能用**,违反 audience 契约 |
| "200 字不够说清楚" | 200 字是硬约束;说不清就再想"为什么用户角度其实就这一句话" |
| "顺便把代码也微调一下" | 改代码不归本 skill;微调单独调 flow-dev-task |
| "UI 改动文字补充更全" | UI 改动文字 ≠ 截图直观;截图先,文字补 |
| "auto-recap=true 但任务很小,跳过吧" | task_type 命中就生成;长度 ≤ 200 一次也不重 |
| "IM 推失败 retry 一次" | 不重试;失败 stop 让用户决定(可能 cc-connect 配置错) |

## Relationship to Other Skills

- **上游(调用本 skill)**:
  - 用户直接触发("讲一下" / "recap")
  - `flow-dev-task` Stage 8 commit 前 pre-hook(条件:task_type ∈ bugfix/merge/accept-review,`--auto-recap=true`)
- **下游**: 无 —— 本 skill 是讲解终点,生成的 markdown 交给调用方处理(IM / commit body / spec)
- **不调用**:
  - `clean-commit`(本 skill 不写 commit;clean-commit 写 commit 不调本 skill — 双向隔离)
  - `director-design`(UI 类改动让上游切到 director-design,本 skill 不主动调)
  - 任何代码修改 skill(本 skill 只解读)
- **不替代**:
  - commit message(技术导向,clean-commit 写)
  - CHANGELOG(产品全局,done mode 写)
  - release notes(跨改动汇总)

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
