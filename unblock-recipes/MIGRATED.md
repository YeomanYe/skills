# unblock-recipes → mem 迁移清单

**迁移日期**: 2026-06-12
**目标 skill**: `mem`(中心仓库 `~/Documents/projects/skills/mem/`)
**过渡期至**: 2026-09-12(3 个月后考虑删除本目录)

---

## 迁移对应关系

### 设计 / 流程

| 原位置 | 新位置 |
|---|---|
| unblock-recipes/SKILL.md 触发硬规则段(symptom-triggered) | mem/SKILL.md "触发硬规则" 段 + mem/references/categories/unblock.md "触发硬规则" 段 |
| unblock-recipes/SKILL.md recipe schema 段 | mem/references/categories/unblock.md "entry 文件 schema" 段 |
| unblock-recipes/SKILL.md Lookup / Writing workflow | mem/SKILL.md Workflow 段(Lookup / Writing / Promote) |
| unblock-recipes/INDEX.md | mem/INDEX.md unblock 段 |
| unblock-recipes/references/constitution.md | 共享 `_shared/constitution.md`(本来就是 sync 来的,**不复制**) |

### Recipes 数据(4 条)

| 原文件 | 新文件 |
|---|---|
| `recipes/lark-project-url-needs-meegle-cli.md` | `mem/data/unblock/lark-project-url-needs-meegle-cli.md` |
| `recipes/lark-wiki-docs-use-lark-cli.md` | `mem/data/unblock/lark-wiki-docs-use-lark-cli.md` |
| `recipes/skillshare-multi-skill-repo-minimal-install.md` | `mem/data/unblock/skillshare-multi-skill-repo-minimal-install.md` |
| `recipes/skillshare-external-repo-wrong-kind.md` | `mem/data/unblock/skillshare-external-repo-wrong-kind.md` |

(`hit_count` / `last_hit` / `first_seen` 全部带过去,**不重置**。)

---

## INDEX 反查表 → mem/INDEX.md unblock 段

原 INDEX 的"按 tag 分类" + "按 symptom 关键词反查" 两段已完整复制进 `mem/INDEX.md` 的 unblock 分类段(slug 全部一致,无修改)。

---

## 老 recipes/ 文件状态

**保留**(不删除,作为历史 archive)。

如果有第三方 skill / 文档引用 `unblock-recipes/recipes/<slug>.md` 的具体路径,这些路径仍可访问,直到本目录被彻底删除。

---

## 触发路由变化

### 之前

`stuck / blocked / loop / 之前踩过吗` 等 → 召回 `unblock-recipes`

### 现在

- `stuck / blocked / loop / 之前踩过吗` 等 → 召回 `mem`(unblock 分类)
- mem description 包含原 unblock-recipes 所有触发关键词,**召回不会漏**
- unblock-recipes frontmatter description 已改为 DEPRECATED 提示,description-based 路由不再选中本 skill

---

## 后续读者指引

### 你是 agent / orchestrator

直接用 mem,本目录不要触发。

### 你是用户想加新 recipe

走 `experience-summary` 分诊路由 → mem(不要再加到本目录的 recipes/)。

### 你是要维护引用的 skill 作者

把 SKILL.md / references 里所有 "unblock-recipes" 改成 "mem"(unblock 分类),或保留过渡期(banner 兜底)。

---

## 过渡期到期(2026-09-12)后

到期后由用户决定:

- **选项 A**: 彻底删除本目录(`rm -rf ~/Documents/projects/skills/unblock-recipes/`)
- **选项 B**: 保留 SKILL.md 当 history note,删除 recipes/ 和其他附属
- **选项 C**: 延期(如果还有外部引用没切干净)

期间若 mem 跑得稳定 / 没有外部漏掉的引用 → 选项 A。
