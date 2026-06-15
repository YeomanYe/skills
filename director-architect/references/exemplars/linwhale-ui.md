# Exemplar — linwhale-ui 的「工程化约束层 + 便捷自动化层」

> 这是一个 **case study / 锚点**，不是模板。用途：架构师在 Step 4 联合评估某项目"门禁是否
> 齐备"时，对照本实例**逐条问"它有的机制，目标项目有没有等价物"**——而不是把这套工具链照搬。
> 本 skill 的判断驱动本质不变：永远基于**目标项目**的证据出方案。
>
> **本文件自包含**：下面内联了实际可移植的配置产物（hook 命令、脚本、配置形状），换任何机器
> 读这一个文件即可重建，不依赖 linwhale-ui 仓库在场。文件路径只作"它当初长在哪"的注脚。
>
> 对应的通用条目见 [`../stack-checklist.md`](../stack-checklist.md) 的「工程化约束与自动化层」节。

## 项目定位

`linwhale-ui` — pnpm workspace monorepo 形态的 React 19 组件库（私有 scoped npm 包），
`packageManager: pnpm@10.31.0`、`engines.node >=18`。规则"文档分域"和"机制化执行"两层都做齐，
是后者（约束 + 自动化）的极佳样本。

---

## 一、可移植产物（实际配置，内联）

### A. Git hooks（husky，`.husky/` 下，每个都极小）

约束类两个 hook 自身只是入口，重逻辑在 lint-staged / commitlint：

```sh
# .husky/pre-commit
pnpm exec lint-staged

# .husky/commit-msg
pnpm exec commitlint --edit ${1}
```

便捷类两个 hook —— **lockfile 变了才自动 install**（省掉"拉完代码忘装依赖"）：

```sh
# .husky/post-merge
. "$(dirname -- "$0")/_/husky.sh"
if git diff --name-only HEAD@{1} HEAD | grep -qE 'pnpm-lock\.yaml|package\.json'; then
  echo "🔄 检测到依赖变更，自动安装..."
  pnpm install
fi

# .husky/post-checkout —— 切分支后同理
. "$(dirname -- "$0")/_/husky.sh"
if [ -n "$(git diff --name-only HEAD@{1} HEAD | grep pnpm-lock.yaml)" ]; then
  echo "🔄 切换分支，检查依赖..."
  pnpm install
fi
```

`package.json` 里靠 `"prepare": "husky"` 在 install 时装好 hooks。

### B. lint-staged 智能过滤（`lint-staged.config.mjs`）

**精髓：门禁只对暂存文件跑、且只跑命中的测试**——这是门禁快到不被 `--no-verify` 绕过的前提。
核心形状（已凝练，保留可重建的关键逻辑）：

```js
// lint-staged.config.mjs（monorepo：lint-staged cwd = 仓库根，组件包在 packages/components）
import fs from 'fs';
import path from 'path';
const PKG = 'packages/components';

// 暂存文件 → 相对组件包的 src 路径（不在 src 下返回 null）
const toPkgRelativeSrc = (file) => {
  const idx = path.resolve(file).indexOf(`/${PKG}/`);
  if (idx === -1) return null;
  const rel = path.resolve(file).slice(idx + `/${PKG}/`.length);
  return rel.startsWith('src/') ? rel : null;
};
// src 路径 → 候选测试文件（src/<dir>/__tests__/<name>.{component,unit}.spec.{ts,tsx}）

export default {
  '*.{js,mjs,ts,tsx}': [
    'eslint --fix',
    // 只跑改动文件命中的测试；零命中就跳过，绝不跑全量套件
    (files) => { /* 推导候选 spec → fs.existsSync 过滤 → vitest run "<命中的 spec>" */ },
    // depcruise 只巡航本次改动的源码：分层/循环门禁对"本次引入的违规"有效，
    // 存量违规由 CI 全量 `pnpm lint:deps` 兜底
    (files) => { /* toPkgRelativeSrc → depcruise <targets> --config .dependency-cruiser.cjs */ },
  ],
  '*.{js,mjs,ts,tsx,json,md,css}': ['prettier --write'],
  '*.ts': [() => 'pnpm -C packages/components exec tsc --noEmit --skipLibCheck'],
};
```

**可迁移的判断**：①门禁只对改动跑（推导命中测试 + 仅改动源码做 depcruise）；②"本次违规即拦、
存量违规 CI 兜底"的分工；③全图分析类工具（knip）不进 pre-commit（喂子集会误报），归 CI。

### C. 聚合 check + 发布门禁（`package.json` scripts）

约束的"总闸"——单命令串起全量门禁，本地 / CI / 发布**共用同一入口**：

```jsonc
// packages/components/package.json —— 聚合 check（远超"只 lint"）
"check": "pnpm build && pnpm lint:publint && pnpm lint:attw && pnpm lint:deps && pnpm size",
"lint:publint": "publint",                       // 发布产物 exports 合规
"lint:attw":    "attw --pack . --profile esm-only ...", // 类型声明包装正确性
"lint:deps":    "depcruise src --config .dependency-cruiser.cjs", // 依赖分层/循环
"size":         "size-limit",                    // 体积卡尺
"prepublishOnly": "pnpm check"                   // 发布即过全量门禁
```

```jsonc
// 根 package.json —— 用 pre* 生命周期把门禁前置，不靠人记得手跑
"prebuild":  "pnpm lint && pnpm -C packages/components typecheck",
"pretest":   "pnpm lint",
"preversion":"pnpm test",
"check":     "pnpm -C packages/components check",
"prepublishOnly": "pnpm check",
"release":   "pnpm -C packages/components check && changeset publish", // changeset publish 不跑 prepublish 钩子，故前置再跑
"version-packages": "changeset version && pnpm install --no-frozen-lockfile"
```

**踩坑沉淀**：`changeset publish` **不**触发 `prepublishOnly` 钩子，所以 `release` 脚本里前置再跑
一次 `check`——**门禁要堵在每一条发布路径上**，不能假设某个钩子一定会触发。

### D. Conventional Commits（commitlint）

```
# 依赖：@commitlint/cli + @commitlint/config-conventional
# commit-msg hook 调 commitlint --edit；强制 feat/fix/docs/... 类型，喂 changesets 自动 changelog
```

### E. 依赖分层守护（`.dependency-cruiser.cjs`，关键 forbidden 规则）

```js
forbidden: [
  { name: 'no-circular',        severity: 'error', comment: '禁止循环/双向依赖 A→B→…→A' },
  { name: 'ui-not-to-composite', severity: 'error', comment: 'primitive(src/ui/*) 不得向上引用 composite' },
]
```
架构边界靠工具强制，不靠 code review 自觉。

### F. 版本/发布（changeset，`.changeset/config.json` 关键字段）

```jsonc
{ "access": "restricted",  // 私有 scoped 包
  "commit": false,         // 不自动提交版本号改动
  "baseBranch": "main",
  "updateInternalDependencies": "patch" }
```

### G. 规则文档分域路由（印证 skill 现有默认结构）

linwhale-ui 的 `docs/` 正是本 skill Step 6 推荐的默认分域（`architecture` / `coding` / `ui` /
`ai-guide`）的真实实例：`docs/index.md` 做总路由（按任务类型指向该读哪些文件），每个域有
`index.md`（导航）+ `rules.md`（总纲）+ 二级专题文件。**印证"每个领域必须同时有 index.md 和
rules.md"那条规则有项目落地过，不是空想**。

---

## 二、项目特有，**不要泛化**

以下是 linwhale-ui 的栈选型 / 组件库专属技巧，评估别的项目时**不要**当成"应该有"：

- **Tailwind 源码/预编译双发布模式** + `add-use-client.mjs` 后处理 —— 组件库 + Tailwind v4 专属
- **Verdaccio 本地 registry 演练** —— 验证发布产物可用性的技巧，适用组件库/SDK，不适用多数应用
- **size-limit 体积卡尺 + tree-shake 验证** —— 组件库/公共 SDK 推荐，普通应用看需要
- **publint / are-the-types-wrong** —— 只有"对外发包"的项目才需要；纯应用不发包则无意义
- **Radix UI + Antd 混用 / dumi 文档框架** —— 设计与技术选型，非工程化规范

---

## 三、怎么用这个 case（给架构师的操作指引）

1. 评估目标项目时**先看它实际是什么**（应用 / 库 / 服务），别拿组件库的全套要求硬套
2. 对「约束 A–F」**逐条问**："目标项目有没有等价机制？没有的话，缺这条的代价是什么？"
3. 缺失的机制按四类问题归类（缺失 / 偏差 / 冗余 / 放错层），写进 research 报告的 finding
4. **不要**因为"linwhale-ui 有 size-limit / publint"就给一个内部工具项目也推荐——
   先判断该机制对**目标项目**是否真有收益（呼应信条：没看目标项目证据就出方案 = 空想）
5. 上面的代码片段可**作为落地脚手架的起点直接改编**（换包路径、换包管理器、删掉发包专属门禁），
   但仍要按目标项目重写，不逐字照抄
