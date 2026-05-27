---
slug: skillshare-external-repo-wrong-kind
symptoms:
  - "skillshare 装外部 repo 后进了 agents/ 而不是 skills/"
  - "skillshare list 显示装好的 skill 在 agent 段不在 skill 段"
  - "期望是 skill 却被自动分类为 agent"
  - "~/.config/skillshare/agents/_<source>/ 出现意外目录"
  - "目标 repo 同时有 skill.json + .claude-plugin/ 等多种 metadata"
first_seen: 2026-05-27
last_hit: 2026-05-27
hit_count: 1
tags: [skillshare]
---

## skillshare-external-repo-wrong-kind — skillshare 装错 kind(agent vs skill)

### 症状信号
- 错误信息典型片段: 无错误,install 静默成功但目录落在 `~/.config/skillshare/agents/_<source>/` 而非 `~/.config/skillshare/skills/_<source>/`
- 行为模式: `skillshare list` 把它列在 agent 段;`~/.claude/skills/` 找不到对应目录;`.skillignore` 反向放行规则也不生效(因为规则匹配 skills/ 路径而文件在 agents/)
- 上下文条件: 目标 repo 根目录同时有 `skill.json`、`.claude-plugin/`、`agents/`、`skills/` 中的 ≥ 2 种,skillshare 自动判定优先级偏向 agent

### 常见错法
- `skillshare install user/repo --track --force`(不带 `--kind`)→ 自动归类,可能装错池
- 装错后只删 `~/.claude/skills/` 下目录 → 源还在 agents/ 池,sync 不会拉到 skills/
- 改 `.skillignore` 加 agent 池路径 → skillignore 只过滤 skills/ 池,管不了 agents/ 池

### 正确做法
**install 时显式 `--kind skill`(或 `--kind agent`),不依赖自动判定**:

1. 已装错的先卸:
   ```
   rm -rf ~/.config/skillshare/agents/_<source-name>
   ```
2. 重装并显式指定 kind:
   ```
   skillshare install user/repo --kind skill --track --force
   ```
3. 验证落在 skills/ 池:
   ```
   ls ~/.config/skillshare/skills/ | grep <source-name>
   skillshare list | grep <skill-name>   # 应在 skill 段
   ```

注意:重装时 skillshare 可能用新源名(如 `_nextlevelbuilder-ui-ux-pro-max-skill` 替代旧的 `_ui-ux-pro-max-official`),`.skillignore` 反向放行规则要跟着用新源名。

### 出处
- 首次发现: 2026-05-27 / 装 nextlevelbuilder/ui-ux-pro-max-skill 时第一次没带 `--kind` 装进 agents/,排查半天才意识到自动判定走错池
- 复现: 1 次
