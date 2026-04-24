# Stack Rule Checklist

这个清单把"常见技术栈 → 该栈对应的最佳实践应该进入哪个规则域"整合到一起。

`project-rules-design` 在设计规则目录时参考它，`flow-project-rules` 在 Step 5 联合评估时也指回这里。两侧共用同一份事实，避免漂移。

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

## 未覆盖栈的处理

如果项目用到的栈不在上表中：

- 不要硬套最接近的条目
- 在规则结构中显式列出"未覆盖的栈"
- 建议用户补充对应的 best-practice skill 或手写规则条目
- `flow-project-rules` 的最终报告必须原样保留这项缺口

## 更新原则

- 新增栈：按上表格式补一节，不要把多个栈混在一节里
- 修改已有栈：保持"域 + 关键点 + 参考 skill"三段结构
- 不在本文件展开具体规则正文，只做"应进入哪个域"的指向
- 具体规则正文由各 best-practice skill 自己承担
