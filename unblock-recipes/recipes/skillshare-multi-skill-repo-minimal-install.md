---
slug: skillshare-multi-skill-repo-minimal-install
symptoms:
  - "skillshare install -s <name> --track 报错 --skill cannot be used with --track"
  - "skillshare target exclude pattern 对带前缀的 slug 不匹配"
  - "整 repo 安装后 60+ 子 skill 全进 ~/.claude/skills/ 污染上下文"
  - "想极简装 multi-skill repo 里的单个 skill 同时保留 update 追踪"
  - "_<source>__skills__<name> 前缀 slug 用 target exclude 排不掉"
first_seen: 2026-05-27
last_hit: 2026-05-27
hit_count: 1
tags: [skillshare]
---

## skillshare-multi-skill-repo-minimal-install — 极简装多 skill repo 的单 skill

### 症状信号
- 错误信息典型片段: `Error: --skill cannot be used with --track`
- 行为模式: 用 `-s <skill>` 选单 skill 配 `--track` 被拒;改用 `skillshare target <agent> --add-exclude "<pattern>"` 排其他 skill 但 pattern 对 `_<source>__skills__<name>` 这种前缀化 slug 不匹配,排不掉
- 上下文条件: 目标 repo 含 N (≥ 5) 个独立 skill,只想用其中 1 个,又要 `skillshare update` 能跟踪更新

### 常见错法
- `skillshare install user/repo -s only-skill --track` → 直接报错
- 装整 repo 后跑 `skillshare target claude --add-exclude "cli-anything-*"` → pattern 不命中前缀化 slug,exclude 失效,60+ skill 仍同步过去
- 删 `~/.claude/skills/` 下不要的目录 → 下次 `skillshare sync --force` 又拉回来

### 正确做法
**整 repo 装 + 根 `.skillignore` 反向放行**(skillshare 同步前过滤,源头干净):

1. 整 repo 装,带追踪:
   ```
   skillshare install user/repo --track --force --kind skill
   ```
2. 编辑 `~/.config/skillshare/skills/.skillignore` 加 4-5 行(gitignore 语法,`!` 反向放行):
   ```
   _<source-name>/**
   !_<source-name>/<path>/<keep-skill>/
   !_<source-name>/<path>/<keep-skill>/**
   ```
   `<source-name>` 跟实际目录名,如 `_HKUDS-CLI-Anything`、`_Leonxlnx-taste-skill`、`_nextlevelbuilder-ui-ux-pro-max-skill`
3. `skillshare sync --force` 应用过滤

### 出处
- 首次发现: 2026-05-27 / 装 HKUDS/CLI-Anything 的 cli-hub-meta-skill、Leonxlnx/taste-skill 的 taste-skill、nextlevelbuilder/ui-ux-pro-max-skill 的 ui-ux-pro-max
- 参考已有反向放行样例:`_frontend-design-official` / `_vercel-react-best-practices-official`
- 复现: 3 次(3 个 repo 都用同一模式)
