# Role Router — flow-codex-goal 任务 → 角色路由规则

> 由 `flow-codex-goal` Phase 0.1 Step 5 使用,自动建议 `extra_reviewers` 清单。
> 路由建议是**建议制**,用户回复 "yes/默认/按你的来" 即接受;**沉默/模糊 → 取默认**。

## 1. 路由原则

- **基于信号路由**,不靠 LLM 猜测(每条规则附**可执行探测命令**)
- **多角色并接**:UI 任务同时需要"视觉师"+"工程师"双重审(AND-pass 严格)
- **不接 = 默认行为**:不写 `extra_reviewers` 段 = 只跑内置 Reviewer Codex(v3 行为)
- **角色边界由 director-* 自己定义**,本路由器只负责"配对",不替角色判断职责

## 2. 任务信号 → 角色映射(主路由表)

### 2.1 UI 视觉任务

| 触发信号 | 推荐 reviewer | 理由 |
|---|---|---|
| GOAL.md `is_ui_task: true` | **director-design**(视觉)+ **director-frontend**(代码) | 视觉师+工程师双角度,前者看用户感知,后者看代码气味 |
| 用户原话含 "页面/UI/dashboard/landing/popup/弹窗/前端界面" | 同上 | UI 任务的同义触发 |
| 任务产出含截图证据(`evidence_paths` 非空 + 含 `.png/.jpg`) | 同上 | 有视觉证据时双审有意义 |

**自动探测命令**:
```bash
# 读 GOAL.md
grep "^is_ui_task: true" GOAL.md
# 看 git diff 是否含 UI 文件
git diff --name-only main 2>/dev/null | grep -qE '\.(tsx|jsx|vue|svelte|html|css|scss)$'
```

### 2.2 纯前端代码任务(无视觉证据)

| 触发信号 | 推荐 reviewer | 理由 |
|---|---|---|
| git diff 含 `*.tsx/jsx/vue/svelte/css` 但 `is_ui_task: false` 或无截图 | **director-frontend** | 单 reviewer 即可,主要审代码结构/边界/AI slop |
| 用户原话含 "重构组件/抽组件/audit JSX/clean up component" | **director-frontend** | director-frontend 触发短语命中 |

**反例(不应接 director-frontend)**:
- 改了 `.html` 但不涉及交互(纯静态文档/邮件模板)
- 改了 `.css` 但只是 design token 微调(走 director-design 即可)

**自动探测命令**:
```bash
# 排除 UI 任务,仅纯代码场景
! grep -q "^is_ui_task: true" GOAL.md && \
  git diff --name-only main 2>/dev/null | grep -qE '\.(tsx|jsx|vue|svelte)$'
```

### 2.3 项目宣发任务

| 触发信号 | 推荐 reviewer | 理由 |
|---|---|---|
| 用户原话含 "宣传/发推/release notes/post to twitter/v2ex/appinn/sspai/Product Hunt" | **director-promote** | 9 维材料 audit(标题钩子/受众匹配/AI slop 等) |
| 任务产出含 `*.md` 文案 + 平台名 | **director-promote** | 文案要按平台调性审 |
| GOAL.md 自定义维度含 "Hook/CTA/Native Feel/Image Safety" | **director-promote** | 维度命中宣发 9 维 |

**反例**:
- 写**技术教程/评测/深度长文**(那是内容写作,非项目宣发)
- 写 **CHANGELOG.md**(纯版本记录,不需 9 维 audit)

**自动探测命令**:
```bash
# 检查 prompt 关键字
grep -iE "宣传|发推|release.*note|post to (twitter|v2ex|appinn|sspai|product.*hunt)|launch on" GOAL.md
```

### 2.4 环境配置/装卸任务

| 触发信号 | 推荐 reviewer | 理由 |
|---|---|---|
| 用户原话含 "装/卸/setup/install/uninstall/环境/dependency" | **director-ops** | 7 维流程 audit(环境探测/备份/验证/知识库) |
| 任务步骤含 `brew install` / `pip install` / `apt install` / `cargo install` | **director-ops** | 装卸触发明确 |

**反例**:
- **项目级依赖**(`npm install` / `pip install -r requirements.txt` 一行)— 那是 flow-dev-task,不走 ops
- **升级已装工具**(`brew upgrade`)— 不走 ops 流程

**自动探测命令**:
```bash
grep -iE "(brew|pip|apt|dnf|cargo|mas) (install|uninstall|remove)" GOAL.md
grep -iE "装一下|卸载|环境配置|install|uninstall|setup" GOAL.md
```

### 2.5 高风险任务(未来)

| 触发信号 | 推荐 reviewer(规划中) | 理由 |
|---|---|---|
| 涉及 auth / 鉴权 / 支付 / 加密 / 密钥 | director-security(未实现) | 安全审计 |
| 涉及 API schema / migration / 跨服务接口 | director-architect(未实现) | 架构审计 |

**当前行为**:这两类只跑内置 Reviewer Codex,在 GOAL.md 备注里标 `# TODO: director-security/architect 实现后接入`。

## 3. 多角色推荐 vs 单角色推荐

| 场景 | 角色数 | 仲裁影响 |
|---|---|---|
| UI 视觉任务 | **2**(design + frontend) | AND-pass 严格度 ↑(任一不过则失败) |
| 纯代码 / 纯宣发 / 纯装卸 | 1 | AND-pass 不变(只 1 个 extra) |
| 混合任务(代码 + 宣发) | 2(frontend + promote) | AND-pass 严格,适合品牌关键页 |
| 极端混合(UI + 宣发 + 装卸) | 3+ | 罕见,建议拆任务而非一次过 3 reviewer |

**经验**:**1-2 reviewer 是甜点,3+ 通常说明任务该拆**。

## 4. 用户决策路径(Question Gate 一轮)

```
orchestrator 探测信号
  ↓
列建议清单 + 一句话理由
  ↓
用户回复
  ├── "yes / 默认 / 按你的来" → 写入 GOAL.md extra_reviewers
  ├── "不要 X" → 移除该 reviewer
  ├── 沉默 / 模糊("差不多") → **取默认**(写入)
  └── 拒绝 → 退出 skill(用户决定不跑 goal)
```

**禁止**:第二轮追问"要不要加 X"(违反 director-* Question Gate 规则)。

## 5. 探测信号汇总(供 Phase 0.1 实现)

```bash
# === UI 任务探测 ===
IS_UI=0
grep -q "^is_ui_task: true" GOAL.md && IS_UI=1
git diff --name-only main 2>/dev/null | grep -qE '\.(tsx|jsx|vue|svelte|html|css|scss)$' && IS_UI=1

# === 宣发任务探测 ===
IS_PROMOTE=0
grep -iE "宣传|发推|release.*note|post to (twitter|v2ex|appinn|sspai)|launch on (product.*hunt)" GOAL.md && IS_PROMOTE=1

# === 装卸任务探测 ===
IS_OPS=0
grep -iE "装一下|卸载|(brew|pip|apt|cargo) (install|uninstall|remove)" GOAL.md && IS_OPS=1

# === 拼装建议清单 ===
SUGGESTED=()
[[ $IS_UI -eq 1 ]] && SUGGESTED+=("director-design" "director-frontend")
[[ $IS_UI -eq 0 ]] && git diff --name-only main 2>/dev/null | grep -qE '\.(tsx|jsx|vue|svelte)$' && SUGGESTED+=("director-frontend")
[[ $IS_PROMOTE -eq 1 ]] && SUGGESTED+=("director-promote")
[[ $IS_OPS -eq 1 ]] && SUGGESTED+=("director-ops")
echo "Suggested extra_reviewers: ${SUGGESTED[@]}"
```

## 6.0. 不重复探测(对齐 director-* 元规范)

orchestrator 在 Phase 0.1 Step 5 路由时,**已确定的字段必须传给下游 director-***,
让它们走"上游已传则不探测"路径(对齐 director-* 元规范 Upstream Handoff Payload 段
的"如果上游已传:本 skill 不重复探测"措辞,以及 `_shared/question-gate.md` 的禁止冗余追问)。

具体传递:

| 字段(orchestrator 已探测) | 传给哪个 director-* | 让它跳过什么 |
|---|---|---|
| `is_ui_task` | director-design / frontend | 跳过 Step 1 项目规范探测中的"是否 UI"判断 |
| `git diff --name-only main` | director-frontend | 跳过 Step 1 "项目内相似实现"扫描的全量 grep |
| `project_root` + `framework` | 全部 4 director-* | 跳过 Step 1 项目根 + 框架探测 |
| `evidence_paths`(截图) | director-design | 跳过 Step 1 Playwright 自截 |
| `objective` | 全部 4 director-* | director-* 直接当 "任务理解" 用,不重复问 |

**禁止**:派 subagent 时只给 reviewer name,不给上述字段(会触发 director-* 自己重新探测,浪费 round)。

## 6. Red Flags(路由器反模式)

- **忽略信号强行推空清单**(明明 `is_ui_task: true` 却不推 director-design)
- **重复推同角色**(同一 reviewer 出现 2 次,浪费 round 资源)
- **跨越界推荐**(纯后端 API 任务推 director-design,无意义)
- **沉默就跳过 Step 5**(沉默 = 取默认,不是跳过 — 默认可能是空清单或推荐清单)
- **第二轮追问**(违反 director-* Question Gate)
- **推未实现的 reviewer**(director-security/architect 还没建,推了 watcher 会 launch 失败)

## 7. Reuse

- 路由示例 + 用例见 `tests/cases.md`(flow-codex-goal 测试用例)
- 自动探测命令统一源 → 本文件第 5 段
- 仲裁规则 → `reviewer-arbitration.md`
- 各 director-* 角色定义 → `~/Documents/projects/skills/director-{design,frontend,promote,ops}/SKILL.md`
