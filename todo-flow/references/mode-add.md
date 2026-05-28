# Mode `add` — 追加带 slug 的 TODO

只做一件事:向 `cwd` 下的 `TODO.md` 追加一条带 slug 的新 TODO。

> 历史:本 mode 在 v1 叫 `init`,v2 改名 `add`(init 让位给真正的初始化 mode)。

## Required Workflow

按以下顺序:

1. 探测环境
2. 一次性收集所需输入(summary + 可选 hints + 可选 depends_on)
3. 生成或校验 slug
4. 追加条目到 TODO.md 正确位置
5. 输出报告

不要在 Step 2 之后还重复追问已知信息。

### Step 1: Probe Environment

```bash
test -f TODO.md && echo "TODO_MD_EXISTS" || echo "TODO_MD_MISSING"
test -d docs/spec && echo "DRIVER_ACTIVE" || echo "DRIVER_INACTIVE"
```

判定:

- `TODO.md` 不存在 → **报告用户先跑 `todo-flow init` 初始化项目**,stop。本 mode 不替用户创建(这是 init mode 的职责)
- `TODO.md` 存在但 `docs/spec/` 不存在 → 同样提示用户跑 `todo-flow init` 把流水线补齐,**但允许继续追加**(TODO 可以照样写)
- 两者都在 → 标准流程

同时收集 TODO.md 中所有已存在的 slug:

```bash
grep -oE '`[a-z0-9][a-z0-9-]*[a-z0-9]`' TODO.md | tr -d '`' | sort -u
```

### Step 2: Collect Inputs (一次问完)

用 **AskUserQuestion** 一次性问完,最多 3 个 question,绝不分轮追问。

| 问题 | 必答? | 说明 |
|---|---|---|
| Summary | 是 | 一句话描述这个 TODO 要做什么 |
| Hints / 约束 | 否 | 任何对实现的偏好或限制;会原样附在 TODO 行末括号里 |
| Depends on(slug 列表)| 否 | 必须在哪些 slug 完成后才能做;逗号分隔 |

如果用户在调用时已经把这些信息**完整**写在 prompt 里 → **不要**再问,直接进 Step 3。

模糊回复("随便"/"都行")→ 取空值默认,不追问。

### Step 3: Generate or Validate Slug

**生成规则**(用户没指定 slug 时):

1. 从 summary 提取 3-5 个关键词(去虚词、动词转名词形式)
2. 中文 summary → 用关键词的英文翻译,例:
   - "支持主题切换" → `theme-toggle`
   - "扩展使用日志" → `extension-usage-log`
   - "多浏览器同步" → `multi-browser-sync`
3. kebab-case 拼接,3-30 字符,仅 `a-z0-9-`
4. 校验唯一性:不在 Step 1 收集的现有 slug 集合中
5. 若冲突 → 加**语义**后缀(`-ui` / `-api` / `-system`),不用数字递增

**手动指定 slug 时**:

- 校验正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`
- 不合法 → 拒绝,给用户合法版本,让用户回 yes/no
- 已存在 → 拒绝,告诉用户在哪一行已经用了
- 这是本 mode 唯一允许的二次追问场景

### Step 4: Append to TODO.md

定位写入位置(优先级):

1. 有 `## Features` 区段 → append 到该区段末尾
2. 有 `## TODO` 或 `## Backlog` 区段 → 同上
3. 都没有 → 在文件末尾新增 `## TODO` 段 + 该条目

条目格式(严格遵守):

```md
- [ ] `<slug>` <title> — <summary>
```

如有 hints,用 `(<hint 1>; <hint 2>; ...)` 拼到行末,**多条 hints 必须用英文分号 `;` 分隔**(详见"Shared Constraints → TODO.md 格式"节),单条 hints 内可自然使用任何标点:

```md
- [ ] `theme-toggle` 主题切换 — 支持深色/浅色/跟随系统三态 (复用 src/hooks/useDarkMode; 不引入新依赖; 必须支持 RTL)
```

收集 hints 时**鼓励一次到位**,每条聚焦一个约束方向(实现倾向 / 范围限制 / 必达指标 / 走查要求 / 已知风险),stage1 起 spec 时会按语义路由到对应章节。

如有 depends_on:**不**写入 TODO.md(depends_on 是 spec 字段,stage 1 起草 spec 时再写),仅在报告中提示。校验每个 depends_on 在 TODO.md 或 `docs/spec/_done/` 中是否存在,不存在的列出来警告但**不阻止**追加。

### Step 5: Verify and Report

```bash
grep -n "^\- \[ \] \`<slug>\`" TODO.md
```

返回 1 行 → 成功,记录行号。
返回 0 或 >1 行 → 写入异常,stop 并报告。

## Output Contract

报告必须包含:

- `mode: add`
- `slug`: 最终 slug
- `title`: 提取的 title
- `line`: 在 TODO.md 中的行号
- `depends_on`: 数组(若提供)
- `depends_warn`: 未找到的依赖 slug 列表(若有)
- `next_step`:
  - 走 todo-flow:`等 stage 1 cron 起草 spec,到时审 docs/spec/<slug>.md`
  - 未启用 todo-flow:`已记录到 TODO.md。你可以手动起草 spec`

## Common Failure Modes

**1. 替用户创建 TODO.md**:可能在不该有 TODO 的目录留下空文件。处理:报告"不存在",提示跑 `todo-flow init`,stop。本 mode 永远不替用户做初始化。

**2. slug 冲突时数字递增**:`theme-toggle` 已存在 → 自动用 `theme-toggle-2`。处理:用语义后缀,或问用户。

**3. 把 hints 当依赖写**:hints 是自由文本写到行末括号;depends_on 必须是合法 slug 引用。

**4. 修改已有 TODO 条目**:本 mode **只追加**,不改已有。即使重复也作为新条目。**改顺序 / 补 hints 应该走 `adjust` mode**。

**5. 在非项目根调用**:只看 cwd 一级,不向上找。
