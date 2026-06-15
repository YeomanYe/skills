# Exemplar — linwhale-ui 的「工程化约束层 + 便捷自动化层」

> 这是一个 **case study / 锚点**，不是模板。用途：架构师在 Step 4 联合评估某项目"门禁是否
> 齐备"时，对照本实例**逐条问"它有的机制，目标项目有没有等价物"**——而不是把这套目录/工具
> 链照搬过去。本 skill 的判断驱动本质不变：永远基于**目标项目**的证据出方案，本文件只提供
> "一个把这层做齐了的真实长什么样"的参照。
>
> 对应的通用条目见 [`../stack-checklist.md`](../stack-checklist.md) 的「工程化约束与自动化层」节。

## 项目定位

`linwhale-ui` — pnpm workspace monorepo 形态的 React 19 组件库（私有 scoped npm 包）。
它把"规则文档分域路由"和"规则的机制化执行"两层都做齐了，是后者（约束 + 自动化）的极佳样本。

## 一、通用可复用范式（值得对照到任何项目）

每条都附 linwhale-ui 里的落盘位置，便于核对"真实项目里它长什么样"。

### 约束（有牙齿）

| 机制 | linwhale-ui 落盘 | 范式要点（可迁移的判断） |
|---|---|---|
| **pre-commit + lint-staged** | `.husky/pre-commit` → `lint-staged.config.mjs` | 只对**暂存文件**跑 eslint --fix + 命中的 vitest + 仅改动源码的 depcruise；把"相对仓库根的暂存路径"换算成"相对组件包的 src 路径"再推导对应测试文件——**门禁只跑相关项，不全量**，这是不被 `--no-verify` 绕过的前提 |
| **commit-msg + commitlint** | `.husky/commit-msg` → `commitlint` | 强制 Conventional Commits（feat/fix/docs/...），`subject-case: lower-case`；为 changesets 自动 changelog 供料 |
| **发布门禁 prepublishOnly** | `packages/components/package.json` `"prepublishOnly": "pnpm check"` | 发布即跑**全量** check（不止 build）。教训沉淀：`changeset publish` 不跑 prepublish 钩子，所以 release 脚本前置再跑一次 check——**门禁要堵在每一条发布路径上** |
| **聚合 check 脚本** | 根 `pnpm check` → `pnpm -C packages/components check` = `build && publint && are-the-types-wrong && lint:deps && size` | 单命令串起 lint/typecheck/test/build + 产物校验（publint / attw）+ 依赖分层（dependency-cruiser）+ 体积（size-limit）；本地与 CI 共用同一入口 |
| **依赖分层守护** | `.dependency-cruiser.cjs` | 禁循环依赖 + 禁 primitive(`src/ui/*`) 向上引用 composite——架构边界靠工具强制，不靠 review 自觉 |

### 便捷（省心）

| 机制 | linwhale-ui 落盘 | 范式要点 |
|---|---|---|
| **post-merge / post-checkout 自动 install** | `.husky/post-merge`、`.husky/post-checkout` | 拉代码 / 切分支后 lockfile 变化自动装依赖，省掉"忘装依赖跑挂了"的反复踩坑 |
| **统一脚本命名** | `check` / `format` / `lint` / `size` / `release` | 一键回归命令名称约定统一，新人不必记长串 |

### 规则文档分域路由（印证 skill 现有默认结构）

linwhale-ui 的 `docs/` 正好是本 skill Step 6 推荐的默认分域（`architecture` / `coding` / `ui` /
`ai-guide`）的真实实例：`docs/index.md` 做总路由（按任务类型指向该读哪些文件），每个域有
`index.md`（导航）+ `rules.md`（总纲）+ 二级专题文件。**这条印证"每个领域必须同时有
index.md 和 rules.md"那条规则不是空想，有项目落地过**。

## 二、项目特有，**不要泛化**

以下是 linwhale-ui 的技术栈选型 / 组件库专属技巧，评估别的项目时**不要**当成"应该有"：

- **Tailwind 源码 / 预编译双发布模式** + `add-use-client.mjs` 后处理 —— 组件库 + Tailwind v4 专属，应用不需要
- **Verdaccio 本地 registry 演练**（`examples/.verdaccio/` + `examples/playground/`）—— 验证发布产物可用性的技巧，适用组件库 / SDK，不适用大多数应用
- **size-limit 体积卡尺 + tree-shake 验证** —— 组件库 / 公共 SDK 推荐，普通应用看需要
- **Radix UI + Antd 混用 / dumi 文档框架** —— 设计与技术选型，非工程化规范

## 三、怎么用这个 case（给架构师的操作指引）

1. 评估目标项目时，**先看它实际是什么**（应用 / 库 / 服务），别拿组件库的全套要求硬套
2. 对"约束 + 便捷"两栏**逐条问**："目标项目有没有等价机制？没有的话，缺这条的代价是什么？"
3. 缺失的机制按四类问题归类（缺失 / 偏差 / 冗余 / 放错层），写进 research 报告的 finding
4. **不要**因为"linwhale-ui 有 size-limit"就给一个内部工具项目也推荐 size-limit——
   先判断该机制对**目标项目**是否真有收益（呼应信条：没看目标项目证据就出方案 = 空想）
