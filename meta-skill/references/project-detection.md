# Project Detection — 探测细则

> Step 1 的并行探测路径具体实现。**只探测 stack + project_type**;砍掉了 stage 推断(本版本不需要)。

## A. 技术栈探测

按以下顺序检查文件存在性 + 解析:

### A.1 package.json(JavaScript/TypeScript 生态)

```bash
test -f package.json && cat package.json | jq '{name, dependencies, devDependencies, scripts, bin, main, type}'
```

**signature mapping**:

| 依赖关键字 / 字段 | 推断 |
|---|---|
| `react` + `react-dom` | stack=react, project_type=frontend |
| `next` | stack=next(隐含 react), project_type=frontend |
| `vue` | stack=vue, project_type=frontend |
| `svelte` | stack=svelte, project_type=frontend |
| `solid-js` | stack=solid, project_type=frontend |
| `electron` | stack=electron, project_type=desktop |
| `tauri-apps/cli` | stack=tauri, project_type=desktop |
| `react-native` / `expo` | stack=react-native, project_type=mobile |
| `wxt` / `plasmo` | stack=react/vue(看 deps), project_type=browser-extension |
| `nest` / `express` / `fastify` / `koa` / `hono` | stack=ts-backend, project_type=backend |
| `prisma` / `drizzle-orm` / `typeorm` | feature=orm → backend 信号增强 |
| `playwright` / `cypress` / `vitest` / `jest` | testing=present(仅记录,不影响 stack) |
| `bin` 字段 + `commander` / `yargs` / `oclif` | project_type=cli |

**package manager 推断**(只用于 plan 摘要,不影响 recommended):

- `pnpm-lock.yaml` → pnpm
- `bun.lockb` → bun
- `yarn.lock` → yarn
- `package-lock.json` → npm
- 多个并存 → 标 `lockfile_conflict`,plan 加 warning

### A.2 其他语言

| 文件 | stack | 常见 project_type 信号 |
|---|---|---|
| `Cargo.toml` | rust | `[[bin]]` → cli;`tauri-apps` → desktop;无 bin 全 lib → library |
| `pyproject.toml` / `setup.py` / `requirements.txt` | python | `django` / `flask` / `fastapi` → backend |
| `go.mod` | go | `gin` / `echo` / `chi` → backend;`cobra` → cli |
| `Gemfile` | ruby | `rails` → backend |
| `composer.json` | php | `laravel` / `symfony` → backend |
| `pubspec.yaml` | dart | `flutter` → mobile |
| `xcodeproj/` 或 `Package.swift` | swift | ios / macos / cli(看 platforms) |
| `gradle*` / `pom.xml` | java / kotlin | `spring-boot` → backend;`android` → mobile |

### A.3 同级 Chrome `manifest.json`

如果项目根有名为 `manifest.json` 的文件且含 `manifest_version` 字段(2 或 3)→ 必为 `project_type=browser-extension`,无论是否同时有 `wxt`/`plasmo` 依赖。

### A.4 多栈混合

允许 `stack` 和 `project_type` 都是数组。常见组合:

- `[react] + [frontend, browser-extension]` — React 扩展(wxt + react)
- `[react] + [frontend, mobile]` — 一个仓库共享 web + RN
- `[rust, react] + [desktop]` — tauri 桌面应用
- `[next] + [frontend, backend]` — Next.js 全栈

Step 2 的 recommended 取并集去重处理。

## B. 项目类型(project_type)兜底逻辑

如果上面 signature 都没命中:

1. 看 `src/`(或主源码目录)结构:
   - 含 `components/` / `pages/` / `app/` → frontend
   - 含 `routes/` / `controllers/` / `handlers/` → backend
   - 含 `popup/` / `background/` / `content/` → browser-extension
   - 含 `cmd/` / `cli/` + 单 entry → cli

2. 看 `scripts` 字段:
   - 含 `dev` / `start` 用 `vite` / `webpack-dev-server` / `next dev` → frontend
   - 含 `serve` / `start:dev` 跑 `node`/`tsx`/`bun` → backend

3. 都不命中 → 标 `project_type=unknown`,plan 列出来让用户在出 plan 时确认/补

## C. 项目规则探测(只作上下文,不驱动 recommended)

按以下顺序读(取存在的第一个,把摘要写到 plan 的"偏好规则"段):

```
CLAUDE.md > AGENTS.md > GEMINI.md > .cursorrules > CONTRIBUTING.md
docs/coding/rules.md
docs/architecture/rules.md
```

提取常见 hint pattern:

| 内容关键词 | hint(摘要给用户看) |
|---|---|
| "use pnpm" / "use yarn" / "don't npm" | "强制 pnpm/yarn,不许 npm" |
| "MobX with makeObservable" | "MobX strict,装饰器禁用" |
| "no class component" / "function component only" | "React 只 function component" |
| "TDD required" / "no skip tests" | "TDD 必须" |
| "don't push to main" / "PR only" | "禁直推 main" |
| "no force push" | "禁 force push" |

**hint 只显示在 plan 摘要里**,不参与 recommended 计算(那是 skill 的事,不是 meta-skill 的)。

## D. 不做的事

明确**不**探测以下内容:

| 项 | 为什么不 |
|---|---|
| stage(bootstrap/dev/debug/finish) | 本版本砍掉;stage 是用户意图,不是代码可探测属性 |
| git log commit 频率 / fix ratio | 同上,砍 stage 之后没用了 |
| `.agent/tasks/` 残留(未完成 codex-goal 等) | 那是 task 状态,跟 skill enable 没直接关系 |
| commit message keyword 聚类 / 痛点分析 | 同上,本 skill 不做痛点画像 |
| `.env` / secrets / 源码内容 | 隐私边界,不读 |

如果用户希望恢复这些信号驱动决策,走 `flow-skill-dev` 加 new feature,**不在本 skill 内偷偷加回**。

## E. 探测失败兜底

| 场景 | 行为 |
|---|---|
| 不是 git repo(根没 `.git`)| **halt**,要求用户 cd 到正确根 |
| 无任何 manifest 文件 | `stack=[]` `project_type=unknown`,plan 列原因,只补 common-fallback 集 |
| 多个 lockfile 共存 | 不影响 stack 探测,plan 加 warning "lockfile_conflict" |
| 探测过程超 5s(读 package.json 等卡住)| halt + 报错,让用户检查 fs / 权限 |

## F. 隐私边界

探测**只读** + 只看以下路径:

- 项目根目录文件名 / 各 manifest 文件 / lock files
- 项目根的 CLAUDE.md / AGENTS.md / CONTRIBUTING.md
- (可选)`src/` 顶层目录列表(只看一层,不递归读源码)

**不读**:

- 源码内容
- `.env` / secrets
- 私有 token / API key
- node_modules / target / dist 等构建产物
