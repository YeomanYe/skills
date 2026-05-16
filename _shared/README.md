# `_shared/` — Skill 之间共享的 reference

## 是什么

`_shared/` 是所有 flow-* skill 共享的 reference 源头。当前包含：

- `parallelization-template.md` — 并行编排规范（6 个 flow-* 引用）
- `handoff-payload-template.md` — handoff payload 字段集（flow-codex-goal 引用）

## 为什么不直接被引用

`skillshare sync` 只同步含 `SKILL.md` 的目录（每个 skill 单独同步到目标，如
`~/.claude/skills/<skill-name>/`）。`_shared/` 没有 `SKILL.md`，**不会**被
skillshare 同步到目标环境。

如果 SKILL.md 引用 `_shared/X.md`，agent 运行时（在目标环境读 skill）会找不到
那个文件，因为 `_shared/` 不在 `~/.claude/skills/` 下。

## 解决方案

修改 `_shared/` 中的文件后，**必须**跑同步脚本把副本复制到每个引用 skill 的
`references/` 目录：

```bash
bash scripts/sync-shared.sh
```

各 SKILL.md 引用路径用 `references/X.md`（同级相对路径），skillshare 同步
到目标后仍可达。

## CI / pre-commit 检查

`scripts/sync-shared.sh --check` 用于检查所有副本是否与 `_shared/` 源头一致。
返回非 0 表示有副本漂移（需要重跑同步）：

```bash
bash scripts/sync-shared.sh --check
# OK: all _shared/ files in sync
# 或
# FAIL: N file(s) drift; run 'bash scripts/sync-shared.sh' to fix
```

建议接入 pre-commit hook 或 CI step，避免源头改了但忘记同步。

## 哪些 skill 引用了什么

| _shared 文件 | 引用 skill |
|---|---|
| `parallelization-template.md` | flow-dev-task / flow-project-finish / flow-project-rules / flow-ext-publish / flow-project-bootstrap / flow-codex-goal |
| `handoff-payload-template.md` | flow-codex-goal |

## 加新共享文件的流程

1. 在 `_shared/` 下新建 `<name>.md`
2. 编辑 `scripts/sync-shared.sh`：在 `SHARED_FILES` 数组加 `<name>.md`，新建对应
   `<name>_target_skills` 数组列出要同步的 skill
3. 在主调 `sync_one` 段加一行调用
4. 跑 `bash scripts/sync-shared.sh` 验证
5. 在引用 skill 的 SKILL.md 写 `references/<name>.md`（不是 `_shared/<name>.md`）
