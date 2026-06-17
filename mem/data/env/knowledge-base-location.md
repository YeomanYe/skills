---
slug: knowledge-base-location
scope: local-host-falcommac-mini
tags: [local-host]
first_seen: 2026-06-17
last_updated: 2026-06-17
hit_count: 0
---

## knowledge-base-location — 个人知识库:写入目录 + 查询工具

**写入 ≠ 查询**:
- **写入知识库** → 直接写文件到目录 `~/Documents/knowledge/`(安装/配置记录、研究笔记、TODOS)
- **查询/检索知识库** → 用 **LLM Wiki 应用**(`~/Applications/LLM Wiki.app`,GUI,nashsu/llm_wiki),不是手动 grep

### 变量/事实清单

| 名称 / 路径 | 用途 | 是否敏感 | 缺失时 |
|---|---|---|---|
| `~/Documents/knowledge` | 知识库根目录(git 仓库)= **写入入口**。装 `<tool>-install.md` / `<tool>-*.md`、研究笔记、`TODOS/` | 否 | 直接用该路径;不存在则确认换机/未同步,不要新建到别处 |
| `~/Applications/LLM Wiki.app` | 知识库 **查询工具**(LLM Wiki,Tauri GUI,基于 LLM 检索) | 否 | 见 `~/Documents/knowledge/llm-wiki-install.md`;未装则按该记录安装 |
| `~/Documents/knowledge/local/.env` | 明文密钥 / token 的**唯一**存放处,权限 600,**不进任何 git** | 是 | 单取 `grep '^NAME=' ... \| cut -d= -f2-`;缺失停下问用户,勿猜 |
| `~/Documents/knowledge/TODOS/` | 待办(`progress.md` / `pending.md` / `done.md`) | 否 | — |

### 读法

- **写**:`Write`/`Edit` 到 `~/Documents/knowledge/<name>.md`(沿用现有格式)。
- **查**:打开 LLM Wiki 应用做语义检索(GUI);agent 侧若要直接读取仍可 `Read` 具体 `.md`。
- **密钥**:`grep '^NAME=' ~/Documents/knowledge/local/.env | cut -d= -f2-`(切勿 `cat` 整份到日志/对话)。

### 出处

- 首次登记: 2026-06-17 / 记录 Tailscale 远程访问配置时确认知识库位置
- 补充: 2026-06-17 / 用户明确"写入用 ~/Documents/knowledge 目录、查询用 llm-wiki"
