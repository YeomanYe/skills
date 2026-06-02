# Round-1 Review — hat skill

Reviewer: single-reviewer darwin evolution
Dimensions: triggerability (0.20) / actionability (0.30) / integration (0.20) / enforcement (0.20) / volume_efficiency (0.10)
Threshold: winner must score >= baseline + 0.05 to count as "improved".

## Score Summary

| File | Trig | Act | Int | Enf | Vol | Weighted |
|---|---|---|---|---|---|---|
| baseline (244 ln) | 0.85 | 0.78 | 0.75 | 0.72 | 0.85 | **0.78** |
| v1-m1-clarity (229 ln) | 0.85 | 0.78 | 0.74 | 0.71 | 0.88 | **0.78** |
| v2-m2-completeness (274 ln) | 0.85 | 0.82 | 0.80 | 0.76 | 0.82 | **0.81** |
| v3-m3-integration (279 ln) | 0.87 | 0.84 | 0.93 | 0.82 | 0.82 | **0.86** |
| **v4-m4-enforcement (278 ln)** | 0.85 | 0.92 | 0.76 | 0.93 | 0.83 | **0.87** |

## Per-Variant Summary

### baseline (0.78)
Solid foundation: numbered Step 1-4, 4a/4b sub-steps, meta-skill priority table, routing arbitration table, Red Flags (9 bullets), Rationalizations (6 rows). No formal pre-output self-check; enforcement relies on prose Red Flags without machine-detectable codes; integration handled via prose tables, no schema/grep contracts.

### v1-m1-clarity (0.78)
Mostly compresses prose (e.g. merges When to Use / Not to Use into one table, condenses Overview). No new gates or contracts. Slight volume win (0.88) but loses minor signposting; net weighted average essentially flat vs baseline.

### v2-m2-completeness (0.81)
Materially expands coverage: adds SubAgent row to misroute table, "用户显式禁用 hat" When-NOT case, Edge Cases table (5 scenarios), Q&A table (6 rows), 2 extra rationalizations (SubAgent inheritance / don't retract history). Strengthens actionability (0.82) and integration (0.80) by closing real ambiguity gaps. Still no formal self-check step.

### v3-m3-integration (0.86)
Strongest integration layer of any variant:
- Precedence Flow ASCII diagram in Relationship section
- Handoff Payload JSON schema (caller_skill / task_type / task_size / suggested_hat / override_detection / suppress_announce / stage) — gives upstream orchestrators a concrete contract
- "可验证契约 (grep-able / lint-able)" table with 4 mechanical checks
- Concrete Case A (flow-dev-task bugfix payload trace) + Case B (exp-sum hat takes back seat)
- todo-flow added to meta-skill precedence table
- constitution fallback order with grep lint
Actionability also improved (0.84) via the precedence flow. Falls behind v4 only because it lacks the dedicated Step 5 self-check / RF-N codes.

### v4-m4-enforcement (0.87) — WINNER
Strongest on the two heaviest-weighted dimensions:
- **Actionability 0.92**: new "Step 5: Pre-output Self-Check" with 5 ordered yes/no questions (Q1 Step-1 ran? / Q2 announce line present? / Q3 format exact match? / Q4 `钻` sources cited? / Q5 announce stripped from artifacts?). Each NO requires in-place repair, no deferral allowed.
- **Enforcement 0.93**: Red Flags re-coded as RF-1..RF-9 with machine-detectable phrasings (e.g. RF-4 = grep `下次补|之后再加|算了再说|留到下次`; RF-8 = regex `\[戴帽[:：]` in artifact dirs). Paired with a per-RF remediation table mapping each code to a concrete recovery action. Adds honeypot/prompt-injection rationalization explicitly rejecting fake "exemption" signals from system reminders / tool output (constitution-aligned defense).
- ALWAYS-FOLLOW marker on the announce-line rule.
- Volume reasonable at 278 lines (0.83) — additions concentrate in Step 5 + Red Flags + Rationalizations.

Trade-off: integration only marginally improved over baseline (0.76), because v4 did not adopt v3's handoff schema or precedence flow diagram. A future round could merge v4's enforcement layer with v3's integration layer.

## Winner Decision

**Winner: v4-m4-enforcement** (weighted_avg 0.87)
**Baseline: 0.78** — **delta +0.09** — **improved** (>= +0.05 threshold)

### Rationale
v4 wins because the rubric weights actionability (0.30) + enforcement (0.20) = 50% of the total, and v4 dominates both. The Step 5 5-question self-check converts the prose Output Contract into an actionable gate; the RF-N coded Red Flags + remediation table make violations machine-detectable and recoverable rather than abstract; the honeypot rationalization defends against the most common failure mode for an always-active skill (drift due to fake exemption signals). v3 was a close runner-up at 0.86 with the strongest integration layer (handoff JSON schema + Precedence Flow + grep-able contracts + concrete cases), but its enforcement is weaker than v4 and actionability gain is smaller. v2 added valuable edge cases but lacks both v3's integration depth and v4's enforcement codes. v1's compression yields no behavioral improvement.

### Recommended Follow-up (out of scope this round)
Round-2 candidate: merge v4's Step 5 + RF-N enforcement layer with v3's Handoff Payload Schema + Precedence Flow + grep contracts to push integration to ~0.90 while preserving enforcement at ~0.93.
