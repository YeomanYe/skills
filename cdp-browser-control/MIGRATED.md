# cdp-browser-control → mem 迁移清单

**迁移日期**: 2026-06-16
**目标 skill**: `mem`(中心仓库 `~/Documents/projects/skills/mem/`)
**过渡期至**: 2026-09-12(3 个月后考虑删除本目录)
**模式**: 参照 [[unblock-recipes]] → mem 的迁移

---

## 迁移对应关系

| 原位置 | 新位置 |
|---|---|
| `cdp-browser-control/SKILL.md` 完整操作流程(核心原理 / 4 步 / 错误速查 / 重连 / 元素定位) | `mem/references/recipes/cdp-browser-control.md` |
| `cdp-browser-control/SKILL.md` frontmatter 触发症状 | `mem/data/unblock/cdp-browser-control-blocked.md`(召回卡 symptoms)+ `mem/INDEX.md` symptom 反查 |
| 触发路由 | `mem/INDEX.md` unblock 分类 / 新 tag `browser-automation` |
| `cdp-browser-control/tests/cases.md` | 行为已由 mem 召回链路覆盖(召回卡命中 → 载入 recipe);原 tests 保留作 archive |

召回卡 `hit_count` 从 1 起算(本次建卡为 first_seen)。

---

## 召回路径变化

### 之前
症状(此浏览器或应用可能不安全 / ECONNREFUSED 9222 / Browser context management not supported / WebSocket 404 等)→ 触发 `cdp-browser-control` skill 直接给流程。

### 现在
- 症状 → 召回 `mem`(unblock 分类) → INDEX 命中 `cdp-browser-control-blocked` 召回卡 → 卡片"正确做法"指向 `mem/references/recipes/cdp-browser-control.md` 完整流程。
- mem description 已含 unblock 死路签名触发;`cdp-browser-control` frontmatter 改为 DEPRECATED,description-based 路由不再选中本 skill。

---

## 已更新的外部引用

| 文件 | 改动 |
|---|---|
| `ext-preflight/SKILL.md` | ECONNREFUSED 行从"参考 cdp-browser-control skill" 改为指向 mem |
| `README.md` | 浏览器自动化 行从 `cdp-browser-control` 改为 `mem(browser-automation)` |

## 尚未更新的引用(follow-up,过渡期 banner 兜底)

| 文件 | 现状 | 说明 |
|---|---|---|
| `meta-skill/references/recommendations.md` | 仍把 `cdp-browser-control` 列为扩展项目推荐安装 skill | 应改推 mem 或移除;改动牵连 `meta-skill/tests/cases.md` 期望集,留待后续 substantial-update |
| `meta-skill/tests/cases.md` | recommended 集仍含 `cdp-browser-control` | 同上,与 recommendations.md 成对改 |
| `_shared/constitution.md` + ~17 份 synced 副本 | "单体工具 skill" 示例列表仍举 `cdp-browser-control` | 纯示例措辞,改一处需 resync ~17 份;低价值,过渡期不破坏 |
| `flow-ext-publish`(SKILL.md / cws-update-submit.md / tests) | 把 "cdp-browser-control" 当**模式名**引用("cdp-browser-control 风格/模式") | **无需改**:是技术模式命名 + flow-ext-publish 已内联执行约束(self-contained),非"去读该 skill"的死链 |

过渡期内目录仍存在 + banner 兜底,上述引用仍可解析,不会断链。

---

## 后续读者指引

- **agent / orchestrator**:直接用 mem,本目录不要触发。
- **想加新 browser-automation 经验**:走 `experience-summary` 分诊 → mem(不要再加到本目录)。
- **维护引用的 skill 作者**:把 "cdp-browser-control" 改成 "mem(browser-automation)" 或保留过渡期 banner 兜底。

## 过渡期到期(2026-09-12)后

- **选项 A**: 彻底删除本目录(`rm -rf ~/Documents/projects/skills/cdp-browser-control/`)。删前先清完上面 follow-up 引用。
- **选项 B**: 保留 SKILL.md 当 history note,删 tests/ 等附属。
- **选项 C**: 延期(若外部引用没切干净)。
