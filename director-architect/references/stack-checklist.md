# Stack Rule Checklist

这个清单把"常见技术栈 → 该栈对应的最佳实践应该进入哪个规则域"整合到一起。

`director-architect` 在 Research Phase Step 4 联合评估时引用本清单（吸收了原 `project-rules-design` + `flow-project-rules` 的功能后，所有规则架构 / 联合评估场景统一引这里，避免漂移）。

## 使用方式

- 评估规范时，先识别项目实际在用的栈
- 对每个识别到的栈，从下表中取对应条目
- 把这些条目映射到项目已有的规则域（`architecture` / `coding` / `ui` / `ai-guide` / 或自定义域）
- 如果该栈的约束没有对应的规则条目，在规则体系中**显式注明缺口**，而不是假装已覆盖

## 栈 → 规则条目对照

### React / Next.js

- **域**：以 `coding` 为主，`architecture` 辅
- **应进入规则的关键点**：
  - Server Component / Client Component 的边界和标记
  - 数据获取位置：`fetch` 在 Server、`use`/`useEffect` 在 Client 的分工
  - 路由段配置：`layout` / `template` / `error` / `loading` / `not-found`
  - 缓存策略：`revalidate` / `dynamic` / `fetch` 的 `next` 参数
  - 性能约束：bundle 拆分、图片优化、字体加载、`'use client'` 泛化风险
- **参考 skill**：`vercel-react-best-practices`

### Preact + Fresh / Islands

- **域**：`architecture` + `coding`
- **应进入规则的关键点**：
  - Island 边界判定：哪些组件需要 hydration、哪些纯 SSR
  - Signals 使用边界：何时 `signal`、何时 `useSignal`、何时普通 state
  - Fresh route handler 的数据获取约束
  - import map 规范：版本锁定位置、加固策略
- **参考 skill**：`developing-preact`、`deno-frontend`

### Deno

- **域**：`architecture` + `coding`（运行期约束）
- **应进入规则的关键点**：
  - permissions（`--allow-read` / `--allow-net` / `--allow-env`）应显式声明
  - import map 与 `deno.json` 的单一事实源
  - Edge / Deploy 运行期限制（无 `fs`、无长驻进程）
  - `std` 版本与三方模块版本锁定策略
- **参考 skill**：`deno-expert`、`deno-frontend`

### Vue / Nuxt

- **域**：`coding` + `architecture`
- **应进入规则的关键点**：
  - SFC 结构：`<script setup>` vs `<script>` 的选择
  - Composition API 边界：composables 文件位置与命名
  - Nuxt 的 `server/`、`composables/`、`utils/`、`plugins/` 各自职责
  - `useFetch` / `useAsyncData` 的缓存键策略
- **参考 skill**：按项目现场匹配

### Svelte / SvelteKit

- **域**：`coding` + `architecture`
- **应进入规则的关键点**：
  - `.svelte` 文件结构：`<script>` / `<style>` / markup 顺序
  - runes（`$state`、`$derived`）vs store 的选择
  - `+page.ts` / `+page.server.ts` / `+layout.ts` 的数据加载分工
- **参考 skill**：按项目现场匹配

### Tailwind / shadcn/ui

- **域**：`ui`（样式组织）+ `coding`（命名）
- **应进入规则的关键点**：
  - `cn` / `cva` / `tv` 的选择与组合
  - variant 设计边界：业务差异不做成 variant
  - primitive / composite 组件分层
  - `components/ui/` 与业务组件的隔离
- **参考 skill**：按项目现场匹配（`frontend-design` 可用作对比参考）

### TypeScript（通用）

- **域**：`coding`
- **应进入规则的关键点**：
  - `tsconfig` 关键 flag 的项目策略：`strict`、`noUncheckedIndexedAccess`、`exactOptionalPropertyTypes`
  - 类型导出位置：跨模块共享 vs 模块内私有
  - 类型断言使用边界
- **参考 skill**：按项目现场匹配

### Go

- **域**：`architecture` + `coding`
- **应进入规则的关键点**：
  - module/package 划分
  - 错误处理：`errors.Is` / `errors.As` / wrap 策略
  - context 传递规范
  - 接口声明位置：consumer 侧 vs provider 侧
- **参考 skill**：按项目现场匹配

### Rust

- **域**：`architecture` + `coding`
- **应进入规则的关键点**：
  - crate / workspace 划分
  - error 类型：`anyhow` / `thiserror` / 自定义 error enum 的选择
  - async runtime 选型（`tokio` / `async-std`）和边界
  - feature flag 使用策略
- **参考 skill**：按项目现场匹配

### Python

- **域**：`architecture` + `coding`
- **应进入规则的关键点**：
  - 包管理：`uv` / `poetry` / `pip-tools` 的选型与锁文件策略
  - 类型标注覆盖度要求（`mypy` / `pyright`）
  - 异步边界：`asyncio` / `anyio` 使用范围
  - 入口脚本 vs 库代码的组织
- **参考 skill**：按项目现场匹配

### Monorepo（pnpm workspace / Nx / Turbo / Lerna）

- **域**：`architecture`
- **应进入规则的关键点**：
  - 包依赖方向：禁止反向依赖或循环依赖
  - 共享代码的提取边界：何时抽 package、何时保留内联
  - 版本策略：workspace 协议、version lock
  - 构建与缓存策略（Turbo remote cache / Nx graph）
- **参考 skill**：按项目现场匹配

### 工程化约束与自动化层（**跨栈通用，不绑定具体栈**）

这一节不是"某个栈的规则"，而是横切所有栈的一问：**项目有没有把规则变成"有牙齿"的
门禁 + "省心"的自动化？** 规则只写在文档里、没有任何机制强制执行 = 跟没人读一样，
等于不存在（呼应本 skill 角色信条"规则是为了被执行，不是写完归档"）。评估任何项目都该
对照这一节，判断"约束有没有落到机制上、便捷有没有省掉重复劳动"。

- **域**：`architecture`（机制与门禁编排）+ `coding`（"完成要求"指向这些门禁）+
  `ai-guide`（交付闸门引用同一套 check）
- **约束（有牙齿，把规则变成无法绕过的门禁）关键点**：
  - **pre-commit hook**（husky / lefthook / simple-git-hooks）→ 配 `lint-staged`，
    **只对暂存文件**跑 lint --fix + format + 相关单测，避免全量拖慢提交
  - **commit-msg hook** → `commitlint` 强制 Conventional Commits（喂给 changesets / 自动 changelog）
  - **发布门禁** → `package.json` 的 `prepublishOnly` / `prepack` 跑**聚合 check**（不止 `build`），
    保证"发布即过全量门禁"，不靠人记得手跑
  - **聚合 check 脚本** → 单命令串起 lint + typecheck + test + build + 产物校验
    （`publint` / `are-the-types-wrong`）+ 依赖分层（`dependency-cruiser`）+ 体积（`size-limit`），
    本地与 CI 共用同一入口
- **便捷（省心，自动化掉重复劳动）关键点**：
  - **post-merge / post-checkout hook** → lockfile 变化时**自动 install**，省掉"拉完代码忘装依赖"
  - 一键本地回归脚本（`check` / `fix`）→ 名称约定统一，新人不必记一长串命令
- **核心判断（评估时重点看）**：
  - 门禁是否**前置到 commit / publish**，而不是只靠 CI 兜底（本地即过 > 推上去才发现）
  - 约束是否**只对改动跑**（lint-staged 智能过滤），否则门禁太慢会被开发者用 `--no-verify` 绕过
  - "有牙齿"和"省心"要配套：只加约束不加便捷 → 开发者烦；只便捷不约束 → 规则形同虚设
- **参考 skill**：`team-frontend-feature-dev`（测试门禁 / 合并前回归）；其余按项目现场匹配
- **具象实例**：见 [`exemplars/linwhale-ui.md`](exemplars/linwhale-ui.md)——一个 pnpm monorepo
  组件库把这一层做齐的真实样本（含每条机制的落盘文件路径）。**实例是用来"对照问目标项目
  有没有等价物"的锚点，不是"照抄这套结构"的模板**。

## 未覆盖栈的处理

如果项目用到的栈不在上表中：

- 不要硬套最接近的条目
- 在规则结构中显式列出"未覆盖的栈"
- 建议用户补充对应的 best-practice skill 或手写规则条目
- `director-architect` 的 research 报告必须原样保留这项缺口

## 更新原则

- 新增栈：按上表格式补一节，不要把多个栈混在一节里
- 修改已有栈：保持"域 + 关键点 + 参考 skill"三段结构
- 不在本文件展开具体规则正文，只做"应进入哪个域"的指向
- 具体规则正文由各 best-practice skill 自己承担
