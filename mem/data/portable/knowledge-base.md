---
slug: knowledge-base
zone: portable
title: 个人知识库位置与调用方式
sync_targets: [claude-auto-memory, codex-agents-md, opencode-agents-md]
---

# 个人知识库(所有 agent 常驻)

- **位置**:`~/Documents/knowledge/`(git 仓库)
- **写入**:直接写文件到该目录;安装/配置记录 `~/Documents/knowledge/<tool>-install.md`;待办 `~/Documents/knowledge/TODOS/`(progress / pending / done)
- **查询(人工)**:LLM Wiki app(`~/Applications/LLM Wiki.app`,nashsu/llm_wiki,GUI 语义检索)
- **查询(agent,无 GUI)**:直接 `ls` / 读 / `grep` `~/Documents/knowledge/` 下的 md 文件(LLM Wiki 是 GUI,agent 用不了)
- **密钥 / token**:明文值**只**存 `~/Documents/knowledge/local/.env`(权限 600,不进任何 git)。单取:`grep '^NAME=' ~/Documents/knowledge/local/.env | cut -d= -f2-`。**绝不把值 `cat` 到对话 / 日志 / commit。**
