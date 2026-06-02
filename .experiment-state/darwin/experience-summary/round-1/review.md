# experience-summary — Darwin Review (Round 1)

**Baseline aggregate**: 0.741 (203 lines)
**Winner**: `v4-m4-enforcement` — aggregate 0.803, delta **+0.062** → `improved` (commit OK)

## Summary Table

| Variant | Lines | Δ vol | trig (0.20) | act (0.30) | int (0.20) | enf (0.20) | vol (0.10) | **aggregate** | Δ vs baseline |
|---|---|---|---|---|---|---|---|---|---|
| baseline | 203 | — | 0.78 | 0.75 | 0.75 | 0.65 | 0.80 | **0.741** | — |
| v1-m1-clarity | 200 | −1% | 0.78 | 0.77 | 0.76 | 0.65 | 0.83 | **0.752** | +0.011 |
| v2-m2-completeness | 282 | +39% | 0.78 | 0.83 | 0.80 | 0.78 | 0.62 | **0.783** | +0.042 |
| v3-m3-integration | 446 | **+119%** | 0.78 | 0.72 | **0.92** | 0.66 | **0.30** | **0.718** | −0.023 |
| **v4-m4-enforcement** | 266 | +32% | 0.78 | 0.82 | 0.76 | **0.92** | 0.65 | **0.803** | **+0.062** |

---

## Per-variant per-dim notes

### v1-m1-clarity (pure compression, 200 lines)

- **triggerability 0.78**: description unchanged. Same 11 trigger phrases EN/中. No gain, no loss.
- **actionability 0.77 (+0.02)**: Step 2 reformatted from bullet list to compact Q-table; Step 3 prior-art moved to table; Layer Map kept as table. Scanning is faster but workflow steps are unchanged. Mild gain.
- **integration 0.76 (+0.01)**: Relationship/handoff section consolidated into a single table (skill/director-*/flow-* | hook | constitution | skill-doctor | sync | L9a). Easier to follow but same content.
- **enforcement 0.65 (=)**: Red Flags & Rationalizations still pointer-only to `references/failure-modes.md`. No real strengthening.
- **volume_efficiency 0.83 (+0.03)**: Same line count, denser per-line value. Best volume/density of the four.
- **Verdict**: clean compress, expected +0.01 only. Compression alone doesn't change behavior.

### v2-m2-completeness (+39%, 282 lines)

- **triggerability 0.78**: description unchanged.
- **actionability 0.83 (+0.08)**: Adds 6 substantive edge-case patches inside the workflow:
  - Step 1.5 PII/credential redact gate (token regex + redact mapping + scope=session fallback)
  - Step 2 fallback A: Q0-Q10 all-no → split-or-discard (no silent halt)
  - Step 2 fallback B: cross-session conflict → STALE marker + supersedes + 90d window
  - Step 2 fallback C: multi-project vs single-project upgrade signals (≥ 2 needed)
  - Step 3 L9a-deferred (no incident → no skeleton)
  - Step 4 stage_switch signal (JSON schema, suppress_followups)
  - Closes real blind spots reviewers/auditors flagged.
- **integration 0.80 (+0.05)**: stage-signal JSON schema is concrete; covers downstream meta-skill consumption.
- **enforcement 0.78 (+0.13)**: Adds disastrous failure modes section (5 must-stop signals). Step 1.5 redact gate is effectively a Red Flag.
- **volume_efficiency 0.62 (−0.18)**: +39% volume — moderate penalty (rubric guide: 0.6-0.7 band).
- **Verdict**: solid +0.042 — strong completeness work, but enforcement and integration are mostly added as prose rather than checkable schemas/checklists, so v4 still beats it.

### v3-m3-integration (+119%, 446 lines) — VOLUME BLOWOUT

- **triggerability 0.78**: description unchanged.
- **actionability 0.72 (−0.03)**: Workflow steps unchanged from baseline, but the file now buries them under a 240-line "Integration Contracts" appendix. Agent scanning to find Step 1-5 is slower, which actively hurts actionability.
- **integration 0.92 (+0.17)**: **best of all variants** — Constitution-fallback callout at top, A) stage-switch JSON schema, B) L9a incident payload schema with enum-enforced `blocker_type`, C) hat precedence rule, D) flow-* boundary table, E) full ASCII flow diagram, F) precedence-table for 6 conflict pairs, G) handoff product file-path table. Genuinely well-designed.
- **enforcement 0.66 (+0.01)**: Red Flags section untouched. Integration ≠ enforcement.
- **volume_efficiency 0.30 (−0.50)**: **+119% smashes through the +20% cap by 6x**. Per the rubric's explicit instruction ("v3 446 lines (+119%) volume_efficiency should be < 0.5"), this is the dominant penalty. The integration value is real but no single skill round should pay 119% volume for it — most of A/B/C/D/E/F/G should live in `references/integration-contracts.md`.
- **Verdict**: regresses below baseline. Good ideas, wrong layer. Should be revisited as a future M3 round with the schemas externalized to `references/`.

### v4-m4-enforcement (+32%, 266 lines) — WINNER

- **triggerability 0.78**: description unchanged.
- **actionability 0.82 (+0.07)**: Pre-action Self-Check SC1-SC5 (evidence / dedupe / redact / hit-position / type) gives agent 5 concrete pre-conditions before Step 2. High-Risk Actions list (10 numbered, with user-gate protocol "yes/确认/行/嗯 = pass, 沉默 / 应该可以 / 你看着办 ≠ pass") makes the gate semantics machine-checkable.
- **integration 0.76 (+0.01)**: Same as baseline. No integration changes.
- **enforcement 0.92 (+0.27)**: **best of all variants** — the full enforcement stack same as hat-r1 / meta-skill-r1 winners:
  - Pre-action Self-Check (5 hard gates with explicit STOP conditions)
  - High-Risk Actions (10 items, each with reason + gate protocol; explicitly rejects vague consent)
  - Red Flags inline (RF1-RF11 with regex/keyword detection — `sk-[A-Za-z0-9]{20,}` / `@[a-z]+\.[a-z]+` / `localhost|10\.|192\.168\.` etc., not a pointer to references)
  - Rationalizations RT1-RT10 (concrete self-deception phrases agent must catch)
  - **Honeypot trap** (planted example "should-look-tempting-but-violates-rules" with correct STOP-because-RF6+RF4+RF11 explanation — same pattern as hat/meta winners)
  - Step 3 self-check: "did I use RT1-RT10? if yes → revert to Step 2"
- **volume_efficiency 0.65 (−0.15)**: +32% — moderate penalty. Best value-per-line of any volume-adding variant.
- **Verdict**: aligns with the strongest enforcement pattern observed in earlier round winners. Delta +0.062 clears the +0.05 commit threshold cleanly.

---

## Decision

- **Winner**: `v4-m4-enforcement` (aggregate 0.803)
- **Delta**: +0.062 vs baseline 0.741
- **Status**: `improved` → eligible for cp to `experience-summary/SKILL.md` + commit
- **Runner-up**: v2-m2-completeness (+0.042) — its 6 edge-case patches are valuable and should be considered for merging into v4 in round 2 (M2+M4 hybrid)
- **v3 lesson**: integration schemas this dense belong in `references/integration-contracts.md`, not SKILL.md body. Consider as a round-2 mutation directive: "M3-lite — add integration schema pointer, keep SKILL.md body within +20%"
