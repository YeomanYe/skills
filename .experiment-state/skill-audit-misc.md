# Skill Audit — 14 Misc Skills (Tools / Tests / Meta)

**Scope**: cdp-browser-control / change-recap / clean-commit / delivery-gate / experience-summary / ext-preflight / hat / project-prep / skill-behavior-test / skill-integration-test / sync-skills / todo-flow / unblock-recipes / web-image

**Shared layer baseline**: constitution.md / output-contract-schema.md / question-gate.md / parallelization-template.md / evidence-discovery.md

---

## Per-skill findings

### 1. cdp-browser-control (150 lines, tool)

**Strengths**:
- Description well-targeted, lists specific failure signals (ECONNREFUSED, "browser context management not supported", WebSocket 404, computer-use read-only)
- Strong 5-step flow + error speedtable + relocation tips
- Has destructive-action gate (pkill confirm) at /Users/falcom/Documents/projects/skills/cdp-browser-control/SKILL.md:52

**Issues**:
- **P1 [Constitution missing]**: Skill performs destructive action `pkill -x "Google Chrome"` (loses unsaved tabs/forms) — exactly the kind of high-risk action constitution.md §6 mandates. SKILL.md inline confirm at line 52 is good but does NOT reference `references/constitution.md`. No `references/` dir at all (Bash check confirmed empty). High-risk tool skill is expected to opt-in to constitution per constitution.md §8.
- **P2 [Test thin]**: tests/cases.md 46 lines, 7 cases — adequate for triggers + error speedtable. Missing: pkill confirm Red Flag case (what if user says "go ahead skip the confirm"? — should refuse), CCC_AUTOPUSH-style env override path (none exists, but test only verifies via positive cases).
- **P2 [Outdated content potential]**: macOS-only paths hardcoded (`$HOME/Library/Application Support/Google/Chrome/Default` at line 32). No Linux/Windows note. If user calls on Linux → silent failure. Not a blocker for current use, but worth a "macOS only" guard in description.
- **P2 [evidence-discovery N/A but uncited]**: skill is "execute" not "audit" — no `_shared/evidence-discovery.md` needed. OK.

**Volume**: 150 lines is fine for a tool skill; content is dense (no padding). No refs split needed.

### 2. change-recap (245 lines, tool/explain)

**Strengths**:
- description very explicit on 3 task_types (bugfix/merge-resolve/accept-review-feedback) + Do NOT use list
- Constitution reference at line 16 (✓)
- Audience parameter clearly contracted, length self-check (200 char hard cap) at Step 4
- output JSON contract follows extension model
- Rationalizations table complete
- IM push failure semantics split by call mode (explicit vs orchestrated) — well-thought-through

**Issues**:
- **P1 [Output Contract — partial schema reference]**: `## Output Contract` (line 182) inlines full JSON without citing `references/output-contract-schema.md` baseline. Per schema.md §11 "引用方式" the first line should be `按 references/output-contract-schema.md 基线 JSON 字段返回 + 本 skill 扩展字段:`. change-recap is also listed in schema.md §"已使用本模板的 skill" (line 182). Missing `verdict`/`must_fix`/`artifact_path` baseline fields — only carries skill-specific fields. **Schema contract violation**.
- **P1 [Audience mismatch in self-check]**: Step 4 says end-user must not contain "framework name" but `pm` allows business module names — but `pm` self-check criteria is not explicit (says "still no file:line" but not "no framework name"). Possibly ambiguous when user passes `--audience pm`.
- **P2 [Test coverage solid]**: 198 lines, 20 cases — covers all 3 task_types × 3 audiences + length guards + non-UI boundary + flow-dev-task orchestration handoff. Strong.

**Volume**: 245 lines is appropriate.

### 3. clean-commit (274 lines, tool)

**Strengths**:
- Tight Mode (select-and-commit / staged-only) split
- IM push logic well-contracted (Step 6 + env override + result enum)
- Common Failure Modes section is 6 named patterns, each with problem→fix

**Issues**:
- **P1 [No constitution reference]**: Performs `git push` (destructive remote-side action), and explicitly disallows force-push. This is a constitution §6 candidate — but SKILL.md lacks the `> 本 skill 受 references/constitution.md 约束` declaration. constitution.md §8 says "单体工具 skill (clean-commit / delivery-gate / web-image / cdp-browser-control 等)按需引用 (高风险操作类必须;纯转换类可选)" — clean-commit explicitly listed as MUST. **References dir is empty** (Bash check confirmed), so no `references/constitution.md` exists either. **Violates constitution.md §8 explicit requirement**.
- **P1 [Output Contract baseline missing]**: `## Output Contract` (line 204) lists fields but doesn't cite schema.md baseline; uses prose checklist instead of JSON. clean-commit is NOT in schema.md target list (line 175-183) — but that may be a deliberate exclusion since it's a single-action tool. Not strictly violation, but inconsistent with similar tools.
- **P2 [Test coverage]**: 75 lines, 13 cases — covers IM push paths (7-13 are good). Could add force-push refusal case.
- **P2 [Inconsistent description format]**: Other tool skills (web-image, change-recap) include explicit "Do NOT use for" in description, clean-commit just has bilingual text with no DO-NOT list. Less precise routing signal.

**Volume**: 274 lines OK; some prose could compress but no waste.

### 4. delivery-gate (413 lines, flow gate)

**Strengths**:
- Strong role 信条 section (lines 19-49) — best-in-class anti-pattern naming
- Two-stage gate clearly defined (review + verification routing)
- Doc-sync conditional trigger (lines 78-126) is thoughtful — avoids rule-binding in prototype phase
- Playwright screenshot/recording rules detailed (lines 207-264)
- IM dispatch routed to `references/im-dispatch.md`

**Issues**:
- **P0 [Downstream skills missing / namespace conflict]**: Routes to `writing-plans` and `verification-before-completion` 9× (lines 12-13, 46-47, 165-167, 198, 385-396). These are **superpowers skill names** (see available-skills list: `superpowers:writing-plans`, `superpowers:verification-before-completion`). delivery-gate is **NOT** namespaced (uses bare names), creating ambiguity:
  - Are these intended to be `superpowers:writing-plans` (external skill)?
  - Or are they internal skills that don't exist in this repo?
  - `ls ~/Documents/projects/skills/` shows NO writing-plans / verification-before-completion / subagent-driven-development / committing-clean-changes directory.
  - **Dead reference** to skills that exist only in the obra-superpowers plugin. Either should namespace as `superpowers:writing-plans` or document the assumption that superpowers is installed.
- **P1 [Constitution not referenced]**: Despite IM dispatching (sending files to external channels = data exfiltration risk per constitution §2/§4/§5), `references/im-dispatch.md` exists but no `references/constitution.md`. constitution.md §8 explicitly lists `delivery-gate` as MUST reference.
- **P1 [Output Contract schema not cited]**: Lines 308-378 inline a 70-line markdown template instead of citing `_shared/output-contract-schema.md` baseline + extensions. delivery-gate is **not** in schema.md target list (line 175-183) but the role (审查 + 闸门) is exactly what schema was designed for. Inconsistency.
- **P1 [No flow-dev-task integration documented]**: delivery-gate is conceptually the gate before flow-dev-task Stage 8 / clean-commit / change-recap (the "收尾三件套"). But SKILL.md never names flow-dev-task as caller. Missing `## Relationship to Other Skills`.
- **P2 [Test coverage]**: 144 lines, 15 cases — covers triggers, doc-sync (4 cases), fail/pass flows, IM degrade. Missing: case for "project gate exists → step-aside" exit path (case 4 only declares it should let-go, not what artifact format the let-go takes).
- **P2 [项目级 gate 路径]**: line 74 `.agents/skills/*-delivery-gate/SKILL.md` — references `.agents/` not `.claude/` or `.skillshare/`. Hardcoded to agents target only.

**Volume**: 413 lines is on the heavy side. The `## 项目成熟期检测与文档同步` section (lines 78-126) is 50 lines — could move to `references/doc-sync-rules.md` and shrink SKILL.md by 35 lines.

### 5. experience-summary (184 lines, meta routing)

**Strengths**:
- Constitution reference at line 6 (✓)
- 12-exit decision tree clearly indexed, judgment-tree.md offloaded to references/
- 5-line output contract format
- Layer Map quick-reference table (lines 119-134)
- Strong rationalizations-to-reject table

**Issues**:
- **P1 [Output Contract schema partial cite]**: References `references/output-contract-template.md` at line 104 — but does NOT cite `references/output-contract-schema.md` baseline at the `## Output Contract` 段. experience-summary IS in schema.md target list (line 175-183). The custom 5-section format is human-facing, but per schema.md §"迁移指南" the JSON baseline + markdown落盘 should still be cited.
- **P2 [Boundary conflict with unblock-recipes]**: experience-summary Q9a routes to unblock-recipes (L9a). unblock-recipes line 57-61 says "本 skill 不接受直接写入 — 唯一入口是 experience-summary". This forms tight coupling: changing Q9a wording in experience-summary requires sync to unblock-recipes write-flow. No mention of this contract in either SKILL.md.
- **P2 [Boundary conflict with hat]**: Both are "meta cross-cutting" skills. experience-summary L0 ("不该沉淀") vs hat self-routing — if user says "戴个性帽" and later "刚踩了坑想沉淀", who routes first? No explicit precedence.
- **P2 [Self-reference section confusing]**: Lines 148-156 "Self-Reference" section says "本 skill 自己=独立 skill,不是 director-*/flow-*/_shared/". Useful for new readers but verbose. Could move to `references/self-reference.md`.

**Volume**: 184 lines is good. Heavy lifting in references/ (10 files, 1900+ lines combined) — appropriate offloading.

### 6. ext-preflight (278 lines, tool)

**Strengths**:
- Clear scope: pre-flight only, NOT publish flow (defers to flow-ext-publish)
- 6 numbered steps +护栏 + report format
- Platform-specific blockers documented (Firefox 2FA / Edge enrollment / CWS $5)

**Issues**:
- **P1 [No constitution reference]**: skill performs network actions (Playwriter sessions, login checks, screenshot generation) but no constitution declaration. Per constitution.md §8 "高风险操作类必须" — ext-preflight uploads to stores via downstream flow-ext-publish so the chain handles secrets/auth. Pre-flight itself is read-only, so this is borderline. **P2 maybe**, marked P1 because IM-screenshot pushes occur via cdp-browser-control downstream.
- **P1 [Outdated commands]**: Line 60 `pip3 install Pillow`, line 273 has same fallback note. With 2026 cutoff, `uv` / `pipx` is preferred; comment says "或: brew install pillow / uv pip install Pillow" — OK actually.
- **P2 [Hard-coded paths]**: `assets/icon.png` / `/tmp/<ext-name>.xpi` etc. — should be parameterized or just example. Description prompts "应根据用户项目的实际路径和工具替换" (line 27) but inline commands don't carry placeholders. Cognitive load.
- **P2 [Test coverage thin]**: 63 lines, 9 cases — covers triggers + main flow + guardrails. Missing: Step 5 Chrome-login-manual-fallback case, Edge-enrollment-redirect-detection case, network-failure during npx playwriter case.
- **P2 [Cross-skill ref dead-ish]**: Line 161 references `cdp-browser-control` skill — alive, OK. Line 9 description says "use flow-ext-publish instead" for end-to-end — alive, OK.

**Volume**: 278 lines is fine. Bash code blocks dominate (~150 lines); could compact but not bloat.

### 7. hat (221 lines, meta persona)

**Strengths**:
- Constitution reference line 18 (✓)
- 8 personas clearly defined with severity ordering (lines 156-167)
- "When NOT to auto-route" table (lines 50-56) addresses obvious false positives
- 设计哲学 section (lines 58-83) defends "no mid-task hat switching" with rationale
- Routing arbitration table (lines 76-84) handles 4 source × precedence
- Notification line format strictly contracted

**Issues**:
- **P1 [Boundary conflict with experience-summary]**: hat自动激活时 (line 8 "每个任务开头默认激活") vs experience-summary 显式调用 — if user prompt simultaneously matches hat auto-route (any task) AND experience-summary trigger ("学到的 xxx 该写到哪"), which runs? No precedence defined. hat is designed to run for EVERY task, so it should not block experience-summary. But hat output notification 末尾 (line 122) is supposed to be appended to final response — does experience-summary's 5-section output contract also get a hat notification? Unclear.
- **P1 [Output Contract baseline]**: Line 169 "## Output Contract (摘要)" notes notification format but doesn't cite `_shared/output-contract-schema.md`. hat IS in schema.md target list (line 175-183) and reference output-contract.md exists. SKILL.md "摘要" properly delegates to `references/output-contract.md` for full contract — good — but the baseline JSON schema isn't visible from SKILL.md. Reader can't see hat's JSON shape from SKILL.md alone.
- **P2 [Severity rank ambiguity]**: 收/问/教 all = severity 3 (line 162-164). The auto-route table at Step 4b uses "目标严格度 > 当前 = 增强切换" — but switching from 收 (3) to 问 (3) is "横向 = opt-in". Three same-level personas means many lateral switches → many opt-in prompts. May feel chatty.
- **P2 [Volume concern]**: 221 lines borderline; SKILL.md has 5 reference files (constitution / detection / output-contract / personas / switching-policy = 968 + 369 lines combined). Heavy offloading is fine; SKILL.md itself OK but the "设计哲学" section (lines 58-83) is unique to hat — could shrink with arrow to reference.

**Volume**: 221 lines borderline acceptable. Personas table + workflow + switching = core. Routing arbitration table could move to switching-policy.md.

### 8. project-prep (259 lines, single-stage flow)

**Strengths**:
- 4 mandatory products clearly defined (MVP / interaction / tech stack / preview)
- Hard exclusion for pure-web projects (line 87-94) — strong anti-pattern
- Preview Required design has 4 hard rules including density / mock / state controller / component reuse
- Anti-rationalizations table is exhaustive (12 entries)

**Issues**:
- **P1 [No constitution reference]**: Single-stage flow with no destructive ops, so constitution.md §8 says "纯转换类可选" — actually OK to omit. **Downgrade to P3 noted.**
- **P1 [Output Contract format - inline only]**: Lines 172-205 inline a markdown structure (no JSON, no `_shared/output-contract-schema.md` reference). project-prep is NOT in schema.md target list. But its output IS structured and used as handoff by flow-project-bootstrap → should be JSON-ready. Inconsistency with neighbor skills.
- **P2 [No tests directory contents at handoff handover paths]**: 237 lines tests/cases.md, 4 triggers + 3 reverse + happy path + guardrail + failure modes. Missing: handoff-to-flow-project-bootstrap case (project-prep is explicitly described as bootstrap's prerequisite — what handoff JSON is required?).
- **P2 [Lots of preview-specific opinions]**: lines 117-157 covers Layout / Mock data richness / State controller / Component reuse — about 40 lines of "preview rules". Could be `references/preview-required-rules.md`, since this is only activated for one path (Required).
- **P2 [Cross-skill ref alive]**: line 27 `flow-project-bootstrap` — alive, OK.

**Volume**: 259 lines slightly heavy; preview rules section (~40 lines) is single-path content.

### 9. skill-behavior-test (291 lines, test)

**Strengths**:
- 4 test modes (auto/mock/context/live) well-differentiated
- Test asset placement convention (fixed cases in skill, ephemeral output in temp dir) clear
- Output structure rigid markdown template

**Issues**:
- **P1 [No constitution reference]**: Test skill, doesn't perform destructive ops — constitution per §8 optional. **OK.**
- **P1 [Output Contract schema not cited]**: lines 224-263 inline markdown template, no JSON, no schema.md citation. **Not in target list** (line 175-183), but test reports are exactly what would benefit from JSON for downstream consumers (CI / integration-test orchestrator). Inconsistency.
- **P1 [Self-test thinness]**: tests/cases.md is only 65 lines, 5 cases (T1/T2 positive, N1/N2 negative, M1 happy, G1/G2/G3 guards). For a 291-line skill, test coverage feels light. Missing: mode auto-selection edge cases (skill targets browser → live? — claim says yes), edge cases on "已有 tests/ 直接复用" path.
- **P2 [Volume]**: 291 lines is heavy for what is essentially 5 steps + 4 modes + output structure. The mode descriptions (lines 42-100) are 60 lines of fairly repetitive content (each mode has 适合测/不适合测 in similar format). Could compact via table.
- **P2 [Dead path - tests/cases.md primary]**: Lines 117-120 "if `<skill>/tests/cases.md`" — assumed file convention, but no enforcement / discoverability help.

**Volume**: 291 lines too heavy — should shrink to ~220 via mode-section compaction.

### 10. skill-integration-test (318 lines, test)

**Strengths**:
- Symmetric to skill-behavior-test (mode model + asset convention)
- Test of "冗余追问" (redundant user questions) is a named concern (lines 289-305)
- Failure should identify "which skill" not just "chain broken"

**Issues**:
- **P1 [Output Contract schema not cited]**: Same as skill-behavior-test — inline markdown template, no schema.md reference.
- **P1 [Test self-coverage thin]**: 71 lines, 5 cases. For 318-line skill, ratio is poor. Missing: "字段保真" failure case (which field gets lost?), "回归场景" example.
- **P1 [Boundary with skill-behavior-test poorly enforced]**: skill-behavior-test N1 routes "测下 flow-dev-task 调用 clean-commit 的链路" → integration-test. integration-test N1 routes "测下 clean-commit 是否正常触发" → behavior-test. Both correct, but only behavior-test has the cross-reference in test cases. integration-test G1 says "用户其实只关心单个 skill 时,建议改用 skill-behavior-test" — but no real example. Easy to misroute.
- **P2 [Volume]**: 318 lines is heaviest of the two test skills. Mode descriptions (lines 41-97) ~55 lines repetitive of skill-behavior-test.
- **P2 [Dispatcher template]**: integration-test references no `references/` — but is a meta skill operating on others, doesn't strictly need it. OK.

**Volume**: 318 lines too heavy; high overlap with skill-behavior-test content (test modes / asset placement / output structure). Recommend extracting `_shared/test-skill-common.md` with mode taxonomy and asset rules to dedupe.

### 11. sync-skills (126 lines, meta)

**Strengths**:
- Tight scope (sync this skill dir to central)
- IM autosync rule clearly defined with env override
- 7 git_status states enumerated

**Issues**:
- **P1 [Constitution not referenced]**: Performs `git push` to central — per constitution §6 "git push 不带 --force / --force-with-lease" is internal rule, but constitution.md §8 still says "高风险操作类必须" for clean-commit-like skills. sync-skills writes to central git repo (potentially shared) — should declare constitution dependency.
- **P1 [Sync target inconsistency]**: Description says "supports either explicit source or cwd, overwriting by default". SKILL.md §约束 (line 124) prohibits writing to `.skillshare/skills/` or `~/.config/skillshare/skills/`. But experience-summary L9a workflow (its SKILL.md line 167-170) says "用户/agent 把 recipe 文件落盘到 `~/Documents/projects/skills/unblock-recipes/recipes/<slug>.md` → commit 到中心 — pre-commit hook 跑 skill-doctor" — that matches sync-skills target. But sync-skills line 41 plugin-prefix-strip logic uses regex `^_<plugin>__(skills__)?<naked>$` — fragile if plugin naming changes.
- **P2 [Test coverage]**: 326 lines tests/cases.md — surprisingly thick for a 126-line skill. Has 7+ cases including default cwd / explicit path / missing SKILL / overwriting / IM autosync. Wait — test cases.md line 14-29 expects target list including `~/.config/skillshare/skills/<dir>` — which CONTRADICTS SKILL.md line 124 "不要偷偷改成项目内 .skillshare/skills/ 或 ~/.config/skillshare/skills/". **Test cases and SKILL.md contradict each other**. Either tests are outdated or SKILL.md update missed test sync.
- **P2 [Outdated test cases]**: tests/cases.md Case 1 line 33-34 lists `~/.config/skillshare/skills/` as expected target. SKILL.md is current (says NOT to write there). Tests outdated.

**Volume**: 126 lines tight, appropriate for a single bash-script wrapping skill.

### 12. todo-flow (222 lines SKILL.md + 14 references = ~3700 lines total)

**Strengths**:
- 6 modes clearly separated, each with独立 reference file
- Mode速查表 + Resolving Mode precedence + per-mode entry sentence — very navigable
- Slug format / language conventions / frontmatter fields — strong shared constraints
- Historical rename compatibility (todo-driver → todo-flow, init → add, review-merge → done) documented
- Templates / Reference Files table (line 196-207) is best-in-class navigation

**Issues**:
- **P0 [Skill bloat — should it be one skill or six?]**: 14 references total (~3700 lines combined), SKILL.md essentially routes to mode-specific reference. The 6 modes (`init` / `add` / `adjust` / `revise` / `exec` / `done`) have wildly different risk profiles:
  - `init` / `add` / `adjust` = low risk, simple file manipulation
  - `revise` = medium risk, status state change
  - `exec` = **medium-high risk** — full orchestrator running stage1→2→3 with subagents, cc-connect, IM push, director-* AND-pass
  - `done` = **核武器 (per role-doctrine.md)** — 4 irreversible actions packed: squash merge + branch deletion + semver bump + CHANGELOG
  - These don't share a "Required Workflow" — each mode has its own. SKILL.md essentially is a dispatcher.
  - **Recommendation**: split into `todo-flow-pipeline` (init/add/adjust = light editing), `todo-flow-revise` (rework spec), `todo-flow-exec` (orchestrator — needs to inherit flow-* metaspec), `todo-flow-done` (merge — could be high-risk skill like clean-commit but heavier).
  - As-is, single skill triggers can route to wildly different action sets — high false-positive risk if user says "todo" near `merge` keyword.
- **P1 [Constitution not referenced]**: `done` mode does merge + push + delete branch + bump version — every action constitution §6 mandates explicit confirmation for. constitution.md §8 says "高风险操作类必须" — todo-flow done is the highest-risk skill of all 14. **No** `references/constitution.md` despite being in sync-shared.sh target list? Check: actually no — `constitution_target_skills` (lines 86-103) does NOT include todo-flow. **Missing from sync-shared.sh target list — should be added.**
- **P1 [Output Contract schema cite weak]**: Lines 182-186 say "跨 skill 基线 JSON schema 见共享文件 references/output-contract-schema.md, 本 skill 各 mode 的字段是基线 + mode 专属扩展". OK partial cite. But each mode's reference (e.g., mode-done.md) must own the extension — not verified here. todo-flow IS in schema.md target list (line 175-183).
- **P1 [Refs split actually appropriate for now]**: User noted "14 refs vs 222 lines SKILL.md" ratio. Looking at usage:
  - 4 cron stage prompts (stage1/2/3-verify / exec-orchestrator) = 1771 lines of prompt text — appropriate as references (LLM-fed text)
  - 6 mode references = 1040 lines total — appropriate
  - state-model = 291 lines (canonical state machine doc) — appropriate
  - role-doctrine + dispatcher-template + output-contract-schema = shared/conventional
  - So 14 refs is justified IF kept as multi-mode dispatcher. Becomes excessive if split into 4-6 skills.
- **P2 [Stage prompt drift risk]**: stage1/2/3 prompts ARE the contract for cron-driven side. SKILL.md line 213 says "改它们等于改 stage 1/2 prompt 端的行为,必须同步审视 init / done 两个 mode 的 references 是否还对齐". This is fragile cross-file invariant with no enforcement test. **Risk**: if stage1-prompt.md adds a frontmatter field, todo-flow add / done don't auto-know.
- **P2 [Test coverage strong]**: 563 lines tests/cases.md is largest in audit. Mode-by-mode coverage including conflicts / depends_on / IM session / merge branches. Good.

**Volume**: SKILL.md 222 lines OK for dispatcher; references appropriate.

### 13. unblock-recipes (312 lines, meta catalog)

**Strengths**:
- Constitution reference line 17 (✓)
- INDEX-first lookup discipline (anti-token-bomb)
- Recipe schema strict (slug regex / symptom min / tags / 4-section / 1KB cap)
- Self-reference section explains "not director / not flow / catalog skill"
- Write-path locked to single entry (experience-summary L9a) — clean coupling
- Lookup workflow has hit-count update mandate including source-repo-vs-clone warning (line 195)

**Issues**:
- **P1 [Cross-skill tight coupling not enforceable]**: line 57 "本 skill 写入入口唯一是 experience-summary 分诊路由". experience-summary Q9a explicitly routes here. But there's NO test in either skill verifying that user-direct-write attempt is refused. unblock-recipes tests/cases.md Case 6 (line 73-79) does cover refuse-direct-write — good. But experience-summary's Q9a routing test doesn't verify the handoff actually reaches unblock-recipes write template.
- **P1 [Symptom signal hard rule conflict with hat]**: Lines 50-55 "症状触发,不是分支触发" hard rule + hat自动激活 design — if hat auto-routes EVERY task, does hat trigger unblock-recipes lookup? unblock-recipes section "When NOT to Use" line 70 says "agent 在做新任务而非卡壳" → not召. OK. But this assumes orchestrator distinguishes — hat doesn't.
- **P2 [INDEX size will grow]**: Current INDEX.md is 86 lines and recipes/ has 4 files. Skill says "后期收敛机制(占位,MVP 不实现)" — but 90-day audit / auto-merge / 复现 threshold all deferred. **Risk**: After 30+ recipes, INDEX symptom table becomes hard to read manually; lookup match becomes noisy. No back-off plan documented.
- **P2 [Recipe content review]**: 4 recipes exist (`lark-project-url-needs-meegle-cli`, `lark-wiki-docs-use-lark-cli`, `skillshare-external-repo-wrong-kind`, `skillshare-multi-skill-repo-minimal-install`). Recipes look real and relevant. Good signal.
- **P2 [Test coverage good]**: 176 lines, 17+ cases including triggers / writing / lookup / guardrails / priority. Solid.

**Volume**: 312 lines slightly heavy. Lookup workflow (lines 183-198) + INDEX format (lines 132-178) + Recipe structure (lines 92-130) are all "canon" — appropriate to keep in SKILL.md (high-frequency read). Could move INDEX format details to `references/INDEX-spec.md` (~30 lines saved).

### 14. web-image (206 lines, tool)

**Strengths**:
- Clear scope (fixed-size web image via HTML/CSS); explicit "do not use for" (illustration / icon system / page UI)
- Hard rules / safe-zone / decoration / verification — opinionated
- Examples directory with case structure
- Cross-skill rule deference (line 184 "上游 skill 的硬规则冲突时遵从上游硬规则")

**Issues**:
- **P1 [No constitution reference]**: constitution.md §8 explicitly lists web-image as "纯转换类可选" — OK to omit. **Downgrade noted, but check**: line 181 covers "图片素材来路不明 / 字体未声明授权" — these are safety concerns. Borderline P2.
- **P1 [Output Contract format]**: lines 144-173 inline markdown — no JSON schema cite. web-image NOT in schema.md target list. OK as-is for transform-tool.
- **P1 [Examples reference fragile]**: line 196 "历史案例存放在 `examples/`" — directory exists. Convention says each case has README.md with "可复用的部分 / 需要按项目改的部分" sections. No automated verification this convention is held. Easy to add invalid examples.
- **P2 [Test coverage thin]**: 58 lines, 5 cases — triggers / special-scenario / reverse / iteration / safety. Missing: examples-folder routing case (when does agent look in examples? — convention says start of task), safe-zone violation case (what does agent do when image MUST overflow?).
- **P2 [Volume]**: 206 lines well-paced; hard rules (lines 81-113) are skill core, output (144-173) baseline. No bloat.

---

## Cross-skill routing conflicts

| # | Conflict | Skills involved | Severity |
|---|---|---|---|
| C1 | "hat default活" vs "experience-summary显式调" — who runs first / does hat append notification to experience-summary output? | hat / experience-summary | P1 |
| C2 | experience-summary L9a → unblock-recipes write contract — coupled but no shared integration test | experience-summary / unblock-recipes | P1 |
| C3 | unblock-recipes自召 (agent loop signal) vs hat自动激活 (every task) — if hat = every task, what stops unblock-recipes spurious召? | hat / unblock-recipes | P2 |
| C4 | delivery-gate routes to `writing-plans` / `verification-before-completion` (superpowers namespace) but uses bare names — dead-ish ref | delivery-gate / superpowers:* | **P0** |
| C5 | clean-commit / change-recap / delivery-gate (收尾三件套) — change-recap explicitly knows about flow-dev-task Stage 8 + clean-commit (双向隔离声明), but delivery-gate doesn't name flow-dev-task or change-recap. Asymmetric awareness. | change-recap / clean-commit / delivery-gate / flow-dev-task | P1 |
| C6 | todo-flow done conflicts with clean-commit — todo-flow line 219 says "todo-flow add/adjust/revise/done自带 commit逻辑,不再调 clean-commit". Good explicit non-call rule, but: does todo-flow done call delivery-gate before merge? No mention. | todo-flow done / clean-commit / delivery-gate | P1 |
| C7 | sync-skills tests/cases.md target list contradicts SKILL.md约束 (tests want `~/.config/skillshare/skills/`, SKILL says NOT to write there) | sync-skills | P1 |
| C8 | skill-behavior-test vs skill-integration-test mutual boundary — N1 cross-refs exist but lightweight; high overlap (~60% duplication of mode taxonomy + asset rules) — extract _shared/test-skill-common.md? | skill-behavior-test / skill-integration-test | P2 |
| C9 | ext-preflight defers Chrome login to "用户手动确认" (line 184-186) while cdp-browser-control would handle programmatically — when does ext-preflight escalate to cdp-browser-control automatically? | ext-preflight / cdp-browser-control | P2 |
| C10 | project-prep is named as flow-project-bootstrap prerequisite (project-prep line 27, line 211-214) — bootstrap should pass handoff. No handoff payload schema shared between them. | project-prep / flow-project-bootstrap | P2 |
| C11 | todo-flow exec calls director-* (line 221) for AND-pass audit. director-* skills exist (5 of them). But todo-flow not in sync-shared.sh constitution target — director-* expects same constitution contract. Drift risk. | todo-flow / director-* | P2 |
| C12 | change-recap audience=dev allows "module names" — but unclear what "module" means for non-frontend codebases. Audience contract ambiguous for backend/CLI projects. | change-recap | P2 |

---

## Constitution / Schema coverage matrix

| Skill | constitution ref? | output-contract-schema ref? | In sync-shared.sh target? |
|---|---|---|---|
| cdp-browser-control | ✗ (high-risk pkill) | n/a (tool) | ✗ |
| change-recap | ✓ | partial (inline JSON, no baseline cite) | ✓ (constitution + schema) |
| clean-commit | ✗ (does git push, **violates §8 explicit list**) | ✗ | ✗ |
| delivery-gate | ✗ (IM dispatch sensitive files, **violates §8 explicit list**) | ✗ (inline 70-line template) | ✗ |
| experience-summary | ✓ | partial (template ref but not schema baseline) | ✓ |
| ext-preflight | ✗ | n/a | ✗ |
| hat | ✓ | delegates to reference | ✓ (constitution + schema) |
| project-prep | ✗ | inline markdown (no JSON) | ✗ |
| skill-behavior-test | ✗ | ✗ (inline markdown) | ✗ |
| skill-integration-test | ✗ | ✗ (inline markdown) | ✗ |
| sync-skills | ✗ (does git push to central) | ✗ | ✗ |
| todo-flow | ✗ (**done mode = 核武器**, NOT in §8 list but should be) | partial | ✓ (schema only) |
| unblock-recipes | ✓ | n/a (catalog skill) | ✓ (constitution) |
| web-image | ✗ (constitution §8 opt-in OK) | ✗ | ✗ |

**Critical gaps** (constitution.md §8 explicit must-cite list NOT honoring):
- **clean-commit** — explicitly named in §8 (line 138), no ref
- **delivery-gate** — explicitly named in §8 (line 138), no ref
- **web-image** — named in §8 (line 138) but as "可选" — OK
- **cdp-browser-control** — named in §8 (line 138) but as "可选" — borderline given pkill

---

## P0 / P1 / P2 summary

### P0 (must-fix, blocking quality)
- **C4**: delivery-gate references `writing-plans` / `verification-before-completion` / `subagent-driven-development` / `committing-clean-changes` 4 dead-ish (superpowers namespace) skill names — 9 occurrences. Either namespace as `superpowers:*` or document assumption.
- **todo-flow split question**: 6 modes with very different risk profiles share one skill — `done` mode is 核武器 per its own role-doctrine but trigger keywords overlap with low-risk `add`. False-positive routing risk on the highest-risk action.

### P1 (should-fix, contract violations)
- **clean-commit**: missing constitution reference despite explicit §8 must-cite + does git push to remote
- **delivery-gate**: missing constitution reference despite explicit §8 must-cite + IM file dispatch
- **delivery-gate**: 50-line inline doc-sync section should move to references/
- **change-recap**: Output Contract baseline JSON schema not cited (in schema.md target list)
- **experience-summary**: Output Contract schema baseline not cited (in target list)
- **todo-flow**: Output Contract schema partial cite; should add to sync-shared.sh constitution_target_skills (done mode = highest risk)
- **hat**: ambiguous interaction with experience-summary when both should fire on same prompt (C1)
- **unblock-recipes**: experience-summary L9a handoff has no integration test (C2)
- **cdp-browser-control**: macOS-only hardcoded paths + no constitution ref despite destructive `pkill`
- **ext-preflight**: no constitution ref + hard-coded `<chrome-build-dir>` etc placeholders not substituted
- **sync-skills**: tests/cases.md contradicts SKILL.md约束 on `~/.config/skillshare/skills/` target (C7)
- **skill-behavior-test / skill-integration-test**: Output Contract schema not cited (test reports are JSON-shape candidates)
- **skill-behavior-test**: 65-line test for 291-line skill — coverage thin
- **skill-integration-test**: 71-line test for 318-line skill — coverage thin
- **project-prep**: Output Contract format inline markdown only; downstream flow-project-bootstrap likely expects structured handoff (C10)
- **change-recap / delivery-gate / clean-commit / flow-dev-task**: asymmetric mutual awareness in 收尾三件套 (C5)
- **todo-flow done vs delivery-gate**: does todo-flow done call delivery-gate before merge? Unspecified (C6)

### P2 (nice-to-fix)
- **delivery-gate**: 413 lines too heavy; doc-sync section (~50 lines) extract candidate
- **skill-behavior-test / skill-integration-test**: ~60% mode-taxonomy + asset-rule duplication; extract `_shared/test-skill-common.md`
- **experience-summary**: 12-line self-reference section verbose, extract to references/
- **hat**: 设计哲学 + routing arbitration tables verbose in SKILL.md; some could move to switching-policy.md
- **project-prep**: 40 lines of preview-Required rules only fire on one branch; extract to `references/preview-required-rules.md`
- **unblock-recipes**: INDEX format spec (~30 lines) could move to `references/INDEX-spec.md`
- **clean-commit**: description lacks explicit "Do NOT use for" list (other tool skills have it)
- **cdp-browser-control**: test cases thin; missing pkill-confirm refusal case
- **web-image**: test cases thin; missing examples-folder routing case + safe-zone violation case
- **ext-preflight**: 5 test cases not enough for 6-step skill
- **sync-skills**: plugin-prefix-strip regex fragile to plugin naming convention changes
- **change-recap**: audience=dev "module name" ambiguous for backend/CLI codebases (C12)
- **todo-flow**: stage1/2/3 prompts ↔ mode references cross-file invariant has no enforcement test
- **unblock-recipes**: deferred收敛机制 (90-day audit, auto-merge, complete-threshold) — no back-off plan once INDEX grows
- **experience-summary vs hat boundary**: precedence ambiguity (C3)
- **ext-preflight ↔ cdp-browser-control**: no auto-escalation path (C9)
- **todo-flow ↔ director-***: should be in constitution target list (C11)

---

## Volume assessment

| Skill | Lines | Verdict |
|---|---|---|
| cdp-browser-control | 150 | OK — dense tool skill, no bloat |
| change-recap | 245 | OK |
| clean-commit | 274 | OK |
| delivery-gate | 413 | **Heavy** — extract doc-sync (~50 lines) |
| experience-summary | 184 | Good — heavy lifting in 10 refs |
| ext-preflight | 278 | OK — bash-block-dominated |
| hat | 221 | Borderline — extract routing-arbitration table |
| project-prep | 259 | Slightly heavy — extract preview-Required rules |
| skill-behavior-test | 291 | **Heavy** — compact mode descriptions, dedupe with integration-test |
| skill-integration-test | 318 | **Heaviest** — dedupe with behavior-test |
| sync-skills | 126 | Tight — appropriate |
| todo-flow | 222 (+3700 refs) | OK as dispatcher; consider splitting if user touches `done` keyword often |
| unblock-recipes | 312 | Slightly heavy — INDEX format extract candidate |
| web-image | 206 | OK |

---

## Recommended priorities

**Top 5 P0/P1 to action**:
1. delivery-gate: namespace the `writing-plans` / `verification-before-completion` etc as `superpowers:*` or document install assumption (**C4**)
2. clean-commit + delivery-gate: add `references/constitution.md` reference (constitution.md §8 explicit violation)
3. delivery-gate + change-recap + experience-summary + todo-flow: cite `_shared/output-contract-schema.md` baseline at `## Output Contract`
4. sync-skills: reconcile tests/cases.md with current SKILL.md (`~/.config/skillshare/skills/` is excluded per SKILL.md but expected per tests)
5. todo-flow: add to `sync-shared.sh` `constitution_target_skills` (done mode = highest-risk in suite)

**Counts**:
- P0: 2
- P1: 18
- P2: 17
- Cross-skill conflicts: 12
