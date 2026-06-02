# Project Detection — 探测细则

> Step 1 的 4 个并行探测路径的具体实现细则。

## A. 技术栈探测

按以下顺序检查文件存在性 + 解析:

### A.1 package.json(JavaScript/TypeScript 生态)
```bash
test -f package.json && cat package.json | jq '{name, dependencies, devDependencies, scripts}'
```

**signature mapping**:

| 依赖关键字 | 推断 |
|---|---|
| `react` + `react-dom` | type=frontend, framework=react |
| `next` | type=frontend, framework=nextjs, ssr=true |
| `vue` | type=frontend, framework=vue |
| `svelte` | type=frontend, framework=svelte |
| `solid-js` | type=frontend, framework=solidjs |
| `electron` | type=desktop, framework=electron |
| `tauri` | type=desktop, framework=tauri |
| `react-native` / `expo` | type=mobile, framework=react-native |
| `wxt` / `plasmo` | type=browser-extension |
| `nest` / `express` / `fastify` / `koa` | type=backend, framework=<name> |
| `prisma` / `drizzle-orm` / `typeorm` | feature=orm,推断 backend |
| `playwright` / `cypress` / `vitest` / `jest` | testing=present |

**package manager 推断**:
- `pnpm-lock.yaml` → pnpm
- `bun.lockb` → bun
- `yarn.lock` → yarn
- `package-lock.json` → npm
- 默认 → npm

### A.2 其他语言

| 文件 | 推断 |
|---|---|
| `Cargo.toml` | language=rust;若 dependencies 含 `tokio` → async, 含 `tauri` → desktop |
| `pyproject.toml` / `setup.py` / `requirements.txt` | language=python;若 `django` / `flask` / `fastapi` → backend |
| `go.mod` | language=go;若 `gin` / `echo` → backend |
| `Gemfile` | language=ruby;若 `rails` → backend |
| `composer.json` | language=php |
| `pubspec.yaml` | language=dart;若 `flutter` → mobile |
| `xcodeproj/` | type=ios |
| `gradle*` / `pom.xml` | language=java/kotlin |

### A.3 多栈混合

允许 `type` 是数组。常见混合:
- `frontend + backend`(monorepo 或全栈)
- `frontend + browser-extension`(扩展含 popup/sidepanel)
- `rust + frontend`(tauri / wxt + rust core)

## B. 项目阶段推断

### B.1 git 信号

```bash
total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
recent_commits=$(git log --since=7.days.ago --pretty=oneline 2>/dev/null | wc -l)
release_tags=$(git tag -l 'v[0-9]*' 'release-*' 2>/dev/null | wc -l)
fix_ratio=$(git log -n 30 --pretty=%s 2>/dev/null | grep -cE '^(fix|revert|hotfix|rollback)' || echo 0)
```

### B.2 阶段判定逻辑

```
if total_commits < 5:
    stage = "bootstrap"
    confidence = 0.9

elif release_tags > 0 and recent_commits > 0:
    if fix_ratio / max(recent_commits, 1) > 0.3:
        stage = "debug"  # 维护中 + 集中修 bug
    else:
        stage = "finish"  # 已 release + 持续维护
    confidence = 0.8

elif release_tags > 0 and recent_commits == 0:
    stage = "finish"  # 已 release 不再活跃
    confidence = 0.7

elif fix_ratio / max(min(recent_commits, 30), 1) > 0.3:
    stage = "debug"  # debug spike
    confidence = 0.6

else:
    stage = "dev"
    confidence = 0.7
```

### B.3 confidence 不足

`confidence < 0.5` → manifest 标 `needs_user_confirmation: true`,要 user 显式选 stage。

## C. 项目规则探测

按以下顺序读(取存在的第一个):

```
CLAUDE.md > AGENTS.md > GEMINI.md > .cursorrules > CONTRIBUTING.md
docs/coding/rules.md
docs/architecture/rules.md
docs/workflow/rules.md
docs/extension/rules.md
```

**提取常见 hint pattern**(grep 后做轻量分类):

| 内容关键词 | hint |
|---|---|
| "use pnpm" / "use yarn" / "don't npm" | `package_manager_locked` |
| "MobX with makeObservable" | `mobx_strict` |
| "no class component" / "function component only" | `react_function_only` |
| "TDD required" / "no skip tests" | `tdd_required` |
| "don't push to main" / "PR only" | `pr_workflow` |
| "no force push" | `no_force_push` |

把命中的 hint 写到 `signals[]` 段供 manifest 用。

## D. 历史 incident 探测

### D.1 git log signals
```bash
git log --since=30.days.ago --pretty=%s | grep -iE 'incident|rollback|revert|hotfix|emergency' | wc -l
```

> 0 → 标 `high_attention: true`,推荐加 `unblock-recipes` + 提示 user 看历史。

### D.2 .agent/ 残留
```bash
find .agent/tasks -name "STATUS.md" -mtime -30 -exec grep -l "STOPPED\|BLOCKED\|abort" {} \;
```

> 0 → 有未完成 / 异常终止的 codex-goal 或 todo-flow 任务,manifest 加 `unfinished_tasks[]`。

### D.3 commit message clue
最近 50 commits 提取 keyword(`bug` / `slow` / `crash` / `leak` / `incident`),聚类 top-3 表征该项目的"痛点",写到 `signals[]`。

## E. 探测失败兜底

| 场景 | 行为 |
|---|---|
| 不是 git repo | stage=`unknown` + 让 user 显式选 |
| 无任何 lock file + 无 source code | 标 `empty_project: true`,manifest 只 enable `project-prep` |
| 多个 lock file 冲突(如 npm + pnpm)| 标 `lockfile_conflict: true`,提示 user 清理一致 |
| 探测过程超 30s | 强 halt,manifest 标 `partial_detection: true` |

## F. 隐私

探测**只读** + 只看以下路径:
- 项目根目录文件名 / package.json / lock files
- git log(metadata,不含 diff content)
- `CLAUDE.md` 等规则文档

**不**读源码内容 / 不读 `.env` / 不读 secrets。这些超出本 skill 范围。
