---
slug: knowledge-base-location
scope: local-host-falcommac-mini
tags: [local-host]
first_seen: 2026-06-17
last_updated: 2026-06-17
hit_count: 0
---

## knowledge-base-location — 个人知识库根目录

### 变量/事实清单

| 名称 / 路径 | 用途 | 是否敏感 | 缺失时 |
|---|---|---|---|
| `~/Documents/knowledge` | 个人知识库根目录(git 仓库)。装安装/配置记录 `<tool>-install.md` / `<tool>-*.md`、研究笔记、`TODOS/` 待办等 | 否 | 直接用该路径;不存在则确认是否换机/未同步,不要新建到别处 |
| `~/Documents/knowledge/local/.env` | 明文密钥 / token 的**唯一**存放处,权限 600,**不进任何 git** | 是 | 见 env 分类读法(方式 A);缺失变量时停下问用户补,不要猜/伪造 |
| `~/Documents/knowledge/TODOS/` | 待办清单(`progress.md` / `pending.md` / `done.md`) | 否 | — |

### 读法

- 知识库文档:直接 `Read ~/Documents/knowledge/<name>.md`。
- 密钥单取:`grep '^NAME=' ~/Documents/knowledge/local/.env | cut -d= -f2-`(切勿 `cat` 整个 .env 到日志/对话)。
- 新增软件安装/配置记录:写 `~/Documents/knowledge/<tool>-*.md`(沿用现有格式)。

### 出处

- 首次登记: 2026-06-17 / 在记录 Tailscale 远程访问配置(`tailscale-remote-access.md`)时确认知识库根目录位置
