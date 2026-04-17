# shadcn-admin: Before / After

这个案例展示一个真实项目如何把混乱规则重构为可路由、可维护、可让 AI 正确消费的规范体系。

## 重构前

旧结构的主要问题：

- 根目录只有一个 `RULE.md`，同时承担总入口和大量正文规则
- `ai/` 目录下堆放编码、UI、架构、AI 协作等多种规则
- 同一条规则经常在入口文件和正文文件重复出现
- AI 很难判断“先读什么、再读什么、什么是总入口、什么是正文”
- 文件划分接近“按历史形成过程堆叠”，而不是按职责分层

典型旧结构：

```text
RULE.md
ai/
  RULES.md
  DESIGN.md
  ARCHITECTURE.md
  I18N.md
  DOCS.md
  CHECKLIST.md
  PLAYBOOK.md
  PROMPTS.md
  DELIVERY-GATE-SKILL.md
```

## 重构目标

目标不是换一批文件名，而是把规则系统改成：

- `CONTRIBUTING.md` 做唯一总入口
- `docs/<domain>/index.md` 做领域入口
- 二级文件只承担具体规则正文
- `architecture`、`coding`、`ui`、`ai-guide` 各自只保留一种职责

## 重构后

```text
CONTRIBUTING.md

docs/
  architecture/
    index.md
    routing.md
    features.md
    component-layering.md

  coding/
    index.md
    rules.md
    naming.md
    comments.md
    data-flow.md
    i18n.md
    docs.md
    completion.md

  ui/
    index.md
    rules.md
    design-system.md
    layout.md
    components.md
    patterns.md

  ai-guide/
    index.md
    prompts.md
    playbook.md
    delivery-gate.md
```

## 关键重构动作

1. 删除旧总纲正文
   - 不再让 `RULE.md` 同时承担入口和规则正文
2. 删除旧 `ai/` 聚合层
   - 不再把所有规则都丢进一个“给 AI 看”的目录
3. 先重做规则分类，再决定文件名
   - 不是把 `DESIGN.md` 机械改名成 `ui.md`
4. 给每个领域加 `index.md`
   - 让人和 AI 都先通过稳定入口进入该领域
5. 让入口只负责路由
   - `CONTRIBUTING.md` 和各领域 `index.md` 不再承载大量正文细节

## 可以复用的模式

- 当现有项目把入口和正文混在一起时，优先先拆入口，再拆正文
- 当现有项目有一个“大杂烩规则目录”时，优先按职责拆域，不按旧文件名搬家
- 当目标是让 AI 能稳定消费规则时，优先保证“入口明确”和“领域边界清楚”
