# Codex 派工 prompt 模板

调 `codex exec` 或 `/codex` 时使用。

## 完整 prompt 结构

```
You are an execution agent dispatched from Claude Code via flow-dev-task.

== Project Context ==
- Repo root: <project root path>
- Read project root AGENTS.md FIRST. It defines coding standards, test commands, and constraints you MUST follow.
- If AGENTS.md is missing, STOP and report error.

== Your Task ==
[粘贴完整 SPEC（见 references/codex-spec-template.md）]

== Execution Rules ==
1. Read AGENTS.md first.
2. Read all files listed in SPEC「范围」 → understand existing patterns.
3. If TDD required: write failing test first → COMMIT → then implement → COMMIT.
4. Run all hard gate commands listed in SPEC「验收」.
5. Do NOT modify files outside SPEC「范围」.
6. Do NOT introduce new dependencies unless explicitly listed in SPEC.
7. Do NOT add mocks / TODOs unless SPEC allows.

== Required Report ==
After implementation, output a JSON block (standalone, not inside markdown fence) following the schema in SPEC「报告要求」.

Important field rules:
- spec_compliance MUST honestly reflect status; "full" means zero deviations.
- tests_written_first MUST be true if TDD was required (verifiable from git log).
- If you couldn't complete the task, set spec_compliance: "broken" and explain in self_assessment.

== Critical ==
Do NOT claim success unless:
- All hard gates passed
- All test commands actually ran
- All files in scope are committed

If anything is unclear in SPEC, output a clarification request instead of guessing.
```

## 使用方式

### 通过 codex CLI

```bash
codex exec --skip-git-repo-check <<'EOF'
[paste full prompt above]
EOF
```

### 通过 codex-plugin-cc（如已安装）

```
/codex [paste full prompt above]
```

### 后台执行（长任务）

```
/codex --background --wait [prompt]
```

## prompt 写作规则

1. **不要简化 prompt**——每个段落都有作用，不要省
2. **AGENTS.md 引用必须明示**——光让 Codex"读项目文件"它会自己挑，不一定读到
3. **JSON 报告 schema 必须给全**——否则 Codex 报告字段会缺
4. **"Critical" 段必须保留**——这是防止 Codex 谎报的核心
5. **不要在 prompt 里说"如果不确定就你看着办"**——这是给 Codex 漂移的许可证

## 返工 prompt 模板

第二次派工（review 失败后）：

```
== Previous Attempt Failed ==
Your previous report claimed: [spec_compliance value]
Actual review found:
- Issue 1: [specific gap, e.g. "tests_passed claimed true but pnpm test --run actually failed"]
- Issue 2: [...]
- Files improperly modified: [...]
- Files in SPEC range but not changed: [...]

== Required Fixes ==
1. Fix [Issue 1] specifically by [...]
2. ...
3. Re-run all hard gate commands and report ACTUAL output.

== Same Constraints as Before ==
[paste original SPEC and rules]

This is attempt N of 3. After 3 failed attempts, the task will be returned to Claude.
```
