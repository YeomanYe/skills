# hat round 3 review

Single variant `v1-hybrid` (304 lines) vs baseline `SKILL.md` (r1 winner, 278 lines, enforcement-heavy).

## Aggregate
- baseline: **0.860**
- v1-hybrid: **0.899**
- delta: **+0.039**
- status: **no_improvement** (< +0.05 threshold; no_improvement_counter += 1)

## Per-dimension scoring

### triggerability (0.20) — description trigger clarity
- **baseline: 0.88** — description has explicit triggers, auto-activation by task type (修复/实现/定位/收尾), do-NOT-route exceptions for hello world / typo / unlocated bug.
- **v1-hybrid: 0.88** — description is **byte-identical** to baseline. No change, no penalty either. Both files share the same frontmatter.

### actionability (0.30) — workflow steps + gates executability
- **baseline: 0.85** — Step 1-5 explicit, Self-Check 5 Q's gated, RF 补救 table per-row.
- **v1-hybrid: 0.91** — Real gains:
  - Severity column **merged into 8-hats table** as source of truth (one less cross-reference table; baseline has them split between Step 4b and main 8 hats).
  - **Q&A 6 boundary section** (Q1: user explicit skip, Q2: disable notif scope, Q3: sub-skill override still runs Step 5, Q4: ≥3 hats → split task, Q5: 钻 + subjective triplet escape, Q6: <5 char user msg). Closes recurring ambiguities baseline left implicit.
  - **ASCII Flow Diagram** visualizes fork (主体 skill yield / constitution fallback / hat own) → Step 5 → output. Modest aid; partially duplicates textual workflow.
  - **Reuse table** adds "何时改这里(而非 SKILL.md)" column → maintainers know where to edit (e.g. detection.md vs personas.md vs SKILL.md).

### integration (0.20) — handoff / cross-skill boundaries
- **baseline: 0.82** — Has the 5-row meta-skill priority table + 5 协同 bullets, but **no schema** for the hat ↔ subskill handoff state.
- **v1-hybrid: 0.92** — Substantive gain:
  - **JSON Handoff Payload Schema** with 7 fields: `hat_persona`, `yielded_to`, `notification_appended_to`, `severity`, `override_source` (auto_detect | user_explicit | sub_skill_override | constitution_fallback), `skip_step_4b`, `exemption_reason`. Lets downstream skills (delivery-gate, exp-sum, change-recap) machine-check the handoff.
  - Meta-skill priority table expanded **+2 rows** (`todo-flow`, `flow-codex-goal`) + **+ handoff field column** mapping each subskill to specific payload values. Concrete contract, not just prose.
  - Brainstorming + systematic-debugging now appear in the table with explicit `sub_skill_override` + persona swap.

### enforcement (0.20) — Red Flags + Rationalizations real guardrails
- **baseline: 0.90** — RF-1..9 fully spelled, 9 rationalizations including the honeypot for self-prompt-injection, 自检失败 判定 explicit. Hard to beat.
- **v1-hybrid: 0.93** — Preserves all RF-1..9 + all 9 rationalizations + honeypot **verbatim**. New on top:
  - **Constitution conflict fallback 5-step protocol** (vs baseline's single-sentence "底线冲突时 hat 退让"): (1) constitution 优先停笔 (2) hat 暂挂不切帽 (3) 完成后回归 hat (4) 告知行照常不加元话术 (5) 不可逆. This closes a real ambiguity—baseline didn't say whether constitution interruption counts toward 4b frequency or triggers hat-switch.
  - Q&A 6 also functions as enforcement scaffolding (e.g. Q5 forbids裸输出主观断言 under `钻`).

### volume_efficiency (0.10) — volume vs value
- **baseline: 0.85** — 278 lines, very dense, minimal padding.
- **v1-hybrid: 0.80** — 304 lines (+26 lines, +9%). The bulk-additions justify themselves:
  - JSON schema (~14 lines) — pure new contract value
  - Q&A table (~10 lines) — directly closes recurring ambiguities
  - Constitution fallback protocol (~9 lines) — fills a real gap
  - ASCII diagram (~28 lines) — partial duplication of Step 1-5 textual flow; minor cost
  - Output Contract canonical section (slight reorg, not net-new)
  - Reuse table extra column (~7 lines) — maintainability gain
  - Net: additions carry weight but +9% volume eats the efficiency dimension's natural budget. Mild penalty justified.

## Aggregate calculation

v1-hybrid:
```
0.88 × 0.20 = 0.176
0.91 × 0.30 = 0.273
0.92 × 0.20 = 0.184
0.93 × 0.20 = 0.186
0.80 × 0.10 = 0.080
total       = 0.899
```

baseline:
```
0.88 × 0.20 = 0.176
0.85 × 0.30 = 0.255
0.82 × 0.20 = 0.164
0.90 × 0.20 = 0.180
0.85 × 0.10 = 0.085
total       = 0.860
```

delta = 0.899 − 0.860 = **+0.039**

## Decision

**status = no_improvement** (delta < +0.05).

Reasoning: v1-hybrid is a genuinely better doc on three dimensions (actionability +0.06, integration +0.10, enforcement +0.03) and the additions are non-cosmetic—JSON handoff schema, constitution fallback protocol, and Q&A are real contracts other skills could machine-read. But:

1. Baseline (r1 winner) is **already near ceiling on enforcement** (RF-1..9 + 9 rationalizations + honeypot + self-check failure judgment). +0.03 is the max realistic gain there.
2. r2 already attempted M3 integration and netted +0.02 only. Hybrid pushes further but hits the same diminishing-returns wall on the trigger / enforcement axes that hat-skill's core protection logic already saturates.
3. +9% volume drags volume_efficiency.

**Recommendation per Darwin protocol**: increment no_improvement_counter; if this is the 3rd consecutive non-breakthrough round, **stop evolving hat** and move to the next skill in the queue (`meta-skill`). v1-hybrid is a legitimate improvement worth a manual cherry-pick (especially the Handoff Payload Schema and Constitution fallback protocol), but doesn't clear the auto-commit bar.
