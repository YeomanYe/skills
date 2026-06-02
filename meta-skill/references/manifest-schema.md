# Manifest JSON Schema + 阶段候选 skill 矩阵

## 1. Manifest JSON 完整 Schema

```jsonc
{
  // 元信息
  "meta_skill_version": "0.1.0",
  "generated_at": "2026-06-03T00:30:00Z",
  "applied_at": null,  // 仅当 user apply 后非 null
  "previous_manifest_hash": null,  // 上一份 manifest 的 sha256,首次为 null

  // 项目特征
  "project": {
    "path": "/Users/me/Documents/projects/example",
    "name": "example",
    "type": ["frontend", "browser-extension"],  // 数组 — 允许多栈混合
    "stage": "dev",  // bootstrap / dev / debug / finish
    "stage_confidence": 0.85,  // 0-1,< 0.5 应 user 确认
    "tech_stack": {
      "languages": ["typescript", "rust"],
      "frameworks": ["react", "wxt"],
      "package_manager": "pnpm",
      "build_tool": "vite"
    }
  },

  // 推断信号(逐项 traceable)
  "signals": [
    {
      "source": "package.json",
      "evidence": "dependencies.wxt present",
      "implies": "type:browser-extension"
    },
    {
      "source": "git log",
      "evidence": "last 30 commits 5% fix/revert, no release tag",
      "implies": "stage:dev"
    },
    {
      "source": "CLAUDE.md",
      "evidence": "Found 'use pnpm not npm' rule",
      "implies": "project_rule:package_manager_locked"
    }
  ],

  // 候选 skill 决策
  "enable": [
    {
      "skill": "flow-dev-task",
      "rationale": "stage=dev 默认包含 flow-dev-task 处理日常 task",
      "priority": "high"
    },
    {
      "skill": "director-frontend",
      "rationale": "type 含 frontend",
      "priority": "high"
    },
    {
      "skill": "cdp-browser-control",
      "rationale": "type 含 browser-extension + 历史 incident 有 selenium-like 失败",
      "priority": "medium"
    }
  ],
  "disable": [
    {
      "skill": "director-architect",
      "rationale": "stage 不是 bootstrap,本项目已有 docs/architecture/",
      "priority": "medium"
    }
  ],
  "keep": [
    {
      "skill": "clean-commit",
      "rationale": "current manifest 已 enable,继续保留"
    }
  ],

  // 用户在 skillshare 单独管的常驻 skill(本 skill 不动)
  "user_managed_always_on": ["hat", "experience-summary", "unblock-recipes"],

  // 跨会话状态
  "last_evaluated_at": "2026-06-03T00:30:00Z",
  "evaluation_count": 3,
  "user_overrides": []  // user 手动改的 skill 列表,本 skill 下次不覆盖
}
```

## 2. 4 阶段 × 技术栈 → 候选 skill 矩阵

### bootstrap(0-5 commits / 无 PRD / 无 architecture docs)

| 通用 | 加成(按 type) |
|---|---|
| `project-prep` | frontend → `director-design` |
| `flow-project-bootstrap` | browser-extension → `ext-preflight`(后期才用,bootstrap 阶段不主动 enable) |
| `director-architect`(规则梳理) | mobile → `huashu-design`(原型) |

### dev(主体开发阶段)

| 通用 | 加成(按 type) |
|---|---|
| `flow-dev-task` | frontend → `director-frontend` / `frontend-design` / `taste-skill` |
| `clean-commit` | browser-extension → `cdp-browser-control`(扩展调试) |
| `change-recap` | backend → `director-architect`(API 规则审) |
| `todo-flow`(若已 init) | rust → `superpowers:test-driven-development`(强制 TDD) |

### debug(最近 30 commits > 30% 含 fix/revert/hotfix)

| 通用 | 加成 |
|---|---|
| `superpowers:systematic-debugging` | 任何 type:`unblock-recipes` |
| 同时**降低** strict skill 推荐(`director-architect` 等)| UI → `cdp-browser-control` + `agent-browser` |

### finish(含 release-* / v[0-9] tag)

| 通用 | 加成(按 type) |
|---|---|
| `flow-project-finish` | browser-extension → `flow-ext-publish` |
| `delivery-gate` | website → `director-promote`(推广) |
| `clean-commit` | library → `flow-skill-dev`(若是 skill 本身) |

## 3. 决策优先级

当多个矩阵命中:
1. user-overrides(优先级最高)
2. project_rule(CLAUDE.md / AGENTS.md 显式 hint)
3. stage-default
4. type-default
5. 兜底常驻(`hat` / `exp-sum` / `unblock-recipes` 由 skillshare 管,不进 manifest)

## 4. 失败模式

- `stage_confidence` < 0.5 → manifest 标 `needs_user_confirmation: true`,user 不 apply 之前不动
- 无 git → 标 `stage: unknown` + 让 user 显式选阶段(不擅自推断)
- skillshare 源里找不到 skill(如 manifest enable 了 `cdp-browser-control` 但 skillshare list-available 没这条)→ 标 `unavailable` + 不写入 enable[],提示 user 装 plugin
