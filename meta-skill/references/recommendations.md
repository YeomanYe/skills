# Recommendations — stack × project_type → skill list

meta-skill 的查表数据。**只列名字 + 一句话用途**,不重复 skill description 的触发短语。

按"baseline by stack" + "add by project_type" + "common-fallback"三段组合,最终 `recommended` 集 = stack baseline ∪ type add ∪ common-fallback,去重。

---

## Common Fallback(所有项目都建议有)

任何项目都该启用的通用调度集。如果全局已有,自然进 `already_global`,不重复 symlink。

| skill | 一句话用途 |
|---|---|
| `flow-dev-task` | 单 task 端到端从需求到 commit |
| `exp-sum` | 任务完成后经验分诊 |
| `unblock-recipes` | agent 卡壳时查跨 agent 错题本 |
| `find-skills` | 临时找有没有某 skill |
| `hat` | 任务开头自动戴个性帽子 |
| `flow-skill-research` | 想装新 skill 前先调研 |

---

## Stack baseline(按主语言/框架)

每行 = 这个 stack 几乎必装的角色 / 流程 skill。

### react / next / vue / svelte / solid(frontend 主流框架)

| skill | 一句话用途 |
|---|---|
| `director-frontend` | 前端工程师视角:JSX 组件实现 / 重构 / 拆边界 / 写代码 |
| `director-design` | 设计师视角:出 mockup / 走查 / 出 variants / handoff |
| `frontend-design` | 反 generic 的高保真 UI / 组件代码 |
| `flow-project-bootstrap` | 项目从零到 kickoff 多阶段 |
| `flow-project-finish` | 项目主体完成后的收尾 + 落地页 + 交付 |

### nextjs(额外)

| skill | 一句话用途 |
|---|---|
| `react-best-practices` | Vercel Engineering 的 React/Next.js 性能模式 |
| `webperf-core-web-vitals` | Core Web Vitals 分析 + 优化 |

### vue / svelte / solid(纯前端,不含 next 性能套件)

(只用上面 react 共享 baseline,不额外加)

### rust

| skill | 一句话用途 |
|---|---|
| `director-architect` | 架构师视角:评估 / 设计 / 重构工程规范体系 |

### python

| skill | 一句话用途 |
|---|---|
| `director-architect` | 规范体系评估 |

### go

| skill | 一句话用途 |
|---|---|
| `director-architect` | 规范体系评估 |

### typescript-pure(无框架,纯 ts)

(只用 common-fallback)

---

## project_type add(在 stack baseline 之上追加)

### browser-extension

| skill | 一句话用途 |
|---|---|
| `cdp-browser-control` | 调试扩展时绕开 sandbox 限制 |
| `flow-ext-publish` | 扩展上架 Chrome/Edge/Firefox 商店 |
| `ext-preflight` | 上架前的 manifest / 权限 / 截图自检 |
| `agent-browser` | 浏览器自动化 + 截图 + 表单 |

### mobile(react-native / expo / flutter)

| skill | 一句话用途 |
|---|---|
| (暂留空,后续按需补) |

### backend(express / nest / fastify / koa / hono)

| skill | 一句话用途 |
|---|---|
| `director-architect` | API / 数据模型 / 规范体系 |
| `director-ops` | 装 / 卸系统级工具(数据库 / runtime) |

### cli

| skill | 一句话用途 |
|---|---|
| `director-architect` | 命令组织 / 子命令规范 |
| `director-ops` | 用户装 / 卸 / 升级流程 |

### chrome-extension(浏览器扩展子集,等价 browser-extension)

(同 browser-extension)

### mixed(多 type 共存,如 frontend + bff)

并集 — 各 type 的 add 全要

---

## Stack 探测信号

| 文件 | 关键 dependency / 字段 | → stack |
|---|---|---|
| `package.json` | `react` + `react-dom` | react |
| `package.json` | `next` | next(隐含 react) |
| `package.json` | `vue` | vue |
| `package.json` | `svelte` | svelte |
| `package.json` | `solid-js` | solid |
| `package.json` | `react-native` / `expo` | react-native(mobile) |
| `package.json` | `electron` | electron(desktop) |
| `package.json` | `tauri-apps/cli` | tauri(desktop) |
| `package.json` | `wxt` / `plasmo` | browser-extension stack |
| `package.json` 同级 `manifest.json` 含 `manifest_version` | — | browser-extension |
| `package.json` | `express` / `koa` / `fastify` / `@nestjs/core` / `hono` | backend |
| `package.json` 只有 `typescript` 无框架 | — | typescript-pure |
| `Cargo.toml` | — | rust |
| `pyproject.toml` / `requirements.txt` | — | python |
| `go.mod` | — | go |
| `pubspec.yaml` | — | flutter |
| `Gemfile` | — | ruby |

多个 manifest 共存(如 `package.json` + `Cargo.toml`)→ 多 stack;`recommended` 取各 baseline 并集。

## project_type 探测信号

| 信号 | → project_type |
|---|---|
| `package.json` 含 `wxt` / `plasmo` 或同级有 Chrome `manifest.json` | browser-extension |
| `package.json` 含 `react-native` / `expo` / `pubspec.yaml` 存在 | mobile |
| `package.json` 含 `electron` / `tauri-apps/cli` | desktop |
| `package.json` 含 `express` / `koa` / `fastify` / `nest` / `hono` | backend |
| `package.json` 含 `bin` 字段 + `commander` / `yargs` / `oclif` | cli |
| `package.json` 含 `react` + 含 SSR(`next`)但无 backend 信号 | frontend |
| 多个 type 信号共存 | mixed(各 type add 并集) |
| 无任何明确信号 | frontend(若有 react/vue/svelte/...);否则 backend / cli 兜底 |

---

## 后续维护

新加 stack / project_type / 替换推荐组合 → 改本文件即可,不需要动 SKILL.md。

如果发现某个组合(如 next + serverless)频繁出现且 baseline 不够 → 加新 section,再在 SKILL.md Step 2 的查表逻辑里多支判定。
