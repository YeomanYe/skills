# portable 分类(持久区 / 跨 agent 常驻事实)

## 是什么

portable 区放 **agent 无关、应被所有 agent 常驻加载** 的引用类事实——它是「跨 agent 常驻记忆」的**单一事实源**,从这里渲染 / 同步进各 agent 各自的常驻载体。

与 env / unblock / staging 的本质区别:那三类是 **on-demand 召回**(symptom → INDEX → 载入命中正文);portable 是 **常驻**(同步进每个 agent 启动就加载的地方,不靠 symptom 触发)。

| | portable(本区) | env / unblock / staging |
|---|---|---|
| 加载方式 | 常驻(同步进各 agent 的 resident loader) | on-demand(symptom→INDEX→载入) |
| 内容 | agent 无关、广泛高频、长期稳定的引用事实 | 环境细节 / 卡壳解法 / 草稿(按需查) |
| 同步 | 同步到 Claude / codex / opencode 的常驻载体 | 不同步,只在 mem 内召回 |

## 何时往里放(四条同时满足)

1. **所有 agent 都该常驻知道**(不是某次任务才需要);
2. **广泛高频**(经常用到);
3. **长期稳定**(不易变);
4. **可公开**(无密钥 / token 明文值)。

任一不满足 → 放 env / unblock(on-demand),不放持久区。
**密钥 / token 明文值永不进此区**(同 mem 全局红线,只存 `~/Documents/knowledge/local/.env`);持久区只放"叫什么 / 在哪 / 怎么读"的引用。

## entry 格式

`data/portable/<slug>.md`,frontmatter:
```yaml
slug: <kebab-case>
zone: portable
title: <一句话标题>
sync_targets: [claude-auto-memory, codex-agents-md, opencode-agents-md]
```
正文用 **agent 无关的 markdown**(不写"我作为 Claude…"之类),便于原样渲染进任意 agent。

## 同步约定(目标载体 + 渲染)

每条 portable entry 的**正文**(去掉 frontmatter)渲染进各 agent 的常驻载体:

| agent | 常驻载体 |
|---|---|
| Claude Code | auto-memory:`~/.claude/projects/<proj>/memory/<slug>.md` + `MEMORY.md` 加一行索引 |
| codex | `~/.codex/AGENTS.md` |
| opencode | `~/.config/opencode/AGENTS.md`(或 opencode.json 的 `instructions`) |

渲染用**哨兵块**包裹,便于幂等覆盖更新(不重复追加):
```
<!-- mem:portable start -->
…(由 data/portable/*.md 渲染,勿手改)…
<!-- mem:portable end -->
```

## 同步执行(本次只定义,不强制跑)

后续可由 `sync-skills` 或专门脚本读 `data/portable/*.md` → 渲染进上述三处哨兵块。
**本次范围:只建区 + 放 `knowledge-base` 一条;实际同步到 codex / opencode 留作后续**(Claude 侧该事实已在 auto-memory `reference_knowledge_base_location.md`,本区是其跨 agent 化的单一事实源)。
