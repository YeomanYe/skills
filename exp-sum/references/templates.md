# Templates —— 各层写作草稿模板

> 按 Q0-Q10 出口分别给的"可直接 copy-paste"模板。

---

## L1 模板: constitution.md 追加段

```markdown
## <段标题>(如 "Output Safety" / "Input Trust Tiers")

<一句话原则>

**该做**:
- <具体动作 1>
- <具体动作 2>

**不该做**:
- <反例 1>
- <反例 2>

**示例**:
- 场景: <when>
- 正确: <good>
- 错误: <bad>
```

**写完后续动作**:
```bash
cd ~/Documents/projects/skills
# 编辑 _shared/constitution.md
bash _scripts/sync-shared.sh  # 分发到 12 skill 的 references/
git add -A && git commit -m "feat(constitution): add <段标题>"
git push origin main
cd ~/.config/skillshare/skills && git pull origin main
skillshare sync --force
```

---

## L2a 模板: _shared/<topic>.md(新元规范)

```markdown
# <Topic Name>

> 由 sync-shared.sh 分发到 <target skill 列表> 的 references/

## 适用范围

本规范约束 <哪些 skill> 在 <哪种场景> 必须遵循的 <结构 / 模式>。

## 必备段(每个目标 skill 必须有)

1. <段名 1>: <要求>
2. <段名 2>: <要求>

## 模板

\`\`\`markdown
<段示例>
\`\`\`

## 反例

- ❌ <反例 1 + 为什么错>
- ❌ <反例 2 + 为什么错>
```

**写完后续动作**:
1. 在 `_scripts/sync-shared.sh` 加入 SHARED_FILES + target 数组
2. 跑 sync-shared.sh + git push + skillshare sync(同 L1)

---

## L2b 模板: skill-doctor 新规则

**目录**: `~/Documents/projects/node-scripts/src/skill-doctor/rules/<rule-name>.ts`

```typescript
import type { Rule, RuleContext, Issue } from '../types';

export const <ruleName>: Rule = {
  name: '<rule-name>',
  severity: 'error' | 'warn',
  description: '<一句话规则说明>',

  async check(ctx: RuleContext): Promise<Issue[]> {
    const issues: Issue[] = [];
    // 1. 收集 skill 文件
    // 2. 检查每个 skill
    // 3. 不满足时 push issue
    return issues;
  },
};
```

**fixture**: `~/Documents/projects/node-scripts/__tests__/skill-doctor/rules/<rule-name>/`(good/ bad/ 各放最小用例)

**test**: `__tests__/skill-doctor/rules/<rule-name>.test.ts`

**写完后续动作**:
```bash
cd ~/Documents/projects/node-scripts
# 走 flow-dev-task: TDD → impl → green → commit
pnpm test
pnpm build
node dist/skill-doctor/index.js --root ~/Documents/projects/skills
```

---

## L3 模板: hook 配置

**位置**: `~/.claude/settings.json`(user 级)或 `<project>/.claude/settings.json`(项目级)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "<your-validation-command>"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "<your-end-of-task-command>"
          }
        ]
      }
    ]
  }
}
```

**常用 hook 事件**:
- `PreToolUse` / `PostToolUse`: 工具调用前后
- `Stop`: 任务结束(主响应完毕)
- `SessionStart`: 会话启动
- `UserPromptSubmit`: 用户消息提交时

**写完后续动作**:
- 用 `update-config` skill 配置,**不要手动编辑 JSON**(避免破坏其他配置)
- 测试: 触发对应事件,确认 hook 执行

---

## L4 模板: script

**目录**: `<project>/scripts/<name>.sh` 或 skill 内 `~/Documents/projects/skills/<skill>/scripts/<name>.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: <script-name> <arg1> <arg2>
# 一句话说明这个脚本做什么

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <args>

Options:
  -h, --help    Show this help

Description:
  <详细说明>
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage; exit 0
fi

# <实际逻辑>
```

**必备**: `chmod +x`、`--help`、`set -euo pipefail`。

---

## L5 模板: nested CLAUDE.md

**位置**: `<project>/<sub-dir>/CLAUDE.md`

```markdown
# <Sub-Dir Name> Conventions

> 本目录(`<sub-dir>/`)特有约束,与项目根 CLAUDE.md 不同。

## 适用范围

本规则只在 `<sub-dir>/` 内的文件生效。

## 约束

1. <约束 1 + 为什么>
2. <约束 2 + 为什么>

## 反例

- ❌ <在本目录里这样写会破坏 X>
```

---

## L6 模板: director-* 修改 / 新建

### 修改现有 director-*

**直接编辑** `~/Documents/projects/skills/director-<role>/SKILL.md` 对应段。

提示: 改完走 `flow-skill-dev` substantial-update(scope → writing-skills → behavior-test → integration-test → sync)。

### 新建 director-*(罕见)

照 `_shared/director-template.md` 13 段标准:
1. frontmatter(name / description)
2. constitution 引用行
3. Overview
4. Trigger
5. Modes
6. Step 0 Question Gate
7. 各 mode Deep Thinking Guide
8. N 维 audit checklist + Aggregate → Verdict 映射(4 档)
9. Output Contract(强制佐证字段)
10. Subagent 派工模板
11. Relationship to other director-*
12. References(constitution / evidence-discovery / question-gate)
13. Reuse(tests/cases.md)

跑 `bash _scripts/sync-shared.sh` 注入共享 references。

---

## L7 模板: flow-* 修改 / 新建

### 修改现有 flow-*

直接编辑对应 SKILL.md 的 Step 段;走 `flow-skill-dev` substantial-update。

### 新建 flow-*(罕见)

参考已有 8 个 flow-* 结构:
- Overview / When to Use / When NOT to Use
- Workflow(分阶段,每阶段强制门)
- Decision Rules(硬写死,不询问)
- Output Contract
- Red Flags / Rationalizations to Reject
- Relationship / Reuse

---

## L8 模板: CLAUDE.md / AGENTS.md 追加

**位置**: `<project>/CLAUDE.md`

```markdown
## <段名>(如 "Commands" / "Architecture" / "Conventions")

<一句话原则>

- <具体规则 1>
- <具体规则 2>

<可选: 反例 / 命令示例>
```

**写之前必做**:
```bash
wc -l <project>/CLAUDE.md
```

如果 ≥ 200 行 → **先把现有"多步流程"段下沉到 skill**,再追加新段。

AGENTS.md(codex 用)通常和 CLAUDE.md 内容一致;可以 symlink:
```bash
ln -sf CLAUDE.md AGENTS.md
```

---

## L9a 模板: unblock-recipes 案例

L9a(跨 agent 卡壳-解法)模板**单独成文**,见 `l9a-recipe-template.md`(symptom + solution 双段 + INDEX.md 两处更新)。本文件不重复,避免漂移。

---

## L9b 模板: auto memory

**位置**: `/Users/falcom/.claude/projects/<project-slug>/memory/<type>_<topic>.md`

```markdown
---
name: <短标题>
description: <一句话描述,用于未来召回>
type: user | feedback | project | reference
---

<memory 正文>

**Why**(仅 feedback/project): <原因>
**How to apply**(仅 feedback/project): <什么时候用>
```

**写完后续动作**: 在同目录 `MEMORY.md` 加一行索引。索引行格式 = 标准 markdown 列表项,链接指向同目录的真实 memory 文件(参考现有 MEMORY.md 风格):

格式说明: 短破折号开头 + 方括号包标题 + 圆括号包文件名 + 破折号 + 一句话钩子。实际文件名要替换成真实文件,例如 `user_preferences.md`。

**4 类速查**:
- `user`: 用户角色 / 知识 / 偏好
- `feedback`: 用户对 agent 的纠正 / 确认(带 Why + How to apply)
- `project`: 项目进行中状态(易过期,需及时更新)
- `reference`: 外部系统资源指针(Linear / Grafana 等)

---

## 通用提示模板

**输出首行必须是【一句话沉淀】**(SKILL.md Step 5 硬约束):

```
【一句话沉淀】把<X 经验>变成了<Y 载体>,沉淀到了<Z 概念位置>。
```

每层的 X/Y/Z 模板见 `layer-map.md` "12 层叙事模板速查"段。禁用词清单见 SKILL.md。

输出末尾附:

```
【后续提醒】
- ☐ 走 flow-skill-dev 完整流程(如果出口是 skill/director-*/flow-*)
- ☐ 跑 sync-shared.sh(如果出口是 _shared/)
- ☐ git push + skillshare sync(如果改了 skills repo)
- ☐ CLAUDE.md 行数超限警告(如果改了 CLAUDE.md 且超 200 行)
- ☐ 用 update-config 配置 hook(如果出口是 hook)
- ☐ 上移检查(如果近期同条经验已被推荐 ≥ 2 次)
```
