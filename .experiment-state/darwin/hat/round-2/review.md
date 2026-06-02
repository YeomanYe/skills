# hat round-2 review

## Setup

- baseline = round-1 winner (v4-m4-enforcement) promoted to `hat/SKILL.md` (278 lines, weighted_avg 0.87)
- 3 challenger variants from 3 mutation strategies (m2 completeness / m3 integration / m5 consolidation)
- scoring same as round 1 (5 dims, weights T 0.20 / A 0.30 / I 0.20 / E 0.20 / V 0.10)

## Scores

| variant | T | A | I | E | V | weighted | Δ vs baseline |
|---|---|---|---|---|---|---|---|
| baseline | 0.85 | 0.92 | 0.76 | 0.93 | 0.83 | **0.870** | — |
| v1-m2-completeness | 0.86 | 0.94 | 0.80 | 0.93 | 0.78 | 0.878 | +0.008 |
| **v2-m3-integration** | 0.86 | 0.90 | 0.95 | 0.94 | 0.72 | **0.892** | **+0.022** |
| v3-m5-consolidation | 0.85 | 0.91 | 0.76 | 0.93 | 0.92 | 0.873 | +0.003 |

## Winner

**v2-m3-integration** at 0.892 (Δ +0.022) — but **does not clear the +0.05 improvement threshold**, so status = `no_improvement`.

## Per-variant findings

### v2-m3-integration (winner, +0.022)
- **What changed**: adds Constitution-conflict 5-step fallback ordering, explicit Handoff Payload JSON schema, ASCII Flow Diagram, 2 new sub_skill rows (brainstorming/systematic-debugging) with handoff columns
- **Strength**: highest integration score (0.95, +0.19 vs baseline) — machine-readable contract surface for hat ↔ host skill state alignment; closes hat-overrides-constitution loophole
- **Trade-off**: heaviest volume (+58 lines), volume_efficiency drops to 0.72
- **Net**: integration gains worth the volume cost; clear winner but not a leap

### v1-m2-completeness (+0.008)
- **What changed**: 6 high-value Q&A entries (explicit-user-hat / disable-notification / sub-skill-override / RF-7 third switch / 钻 on subjective / <5字 scope), todo-flow + flow-codex-goal added to meta-skill table, reuse change-location table
- **Strength**: actionability up (+0.02) — Q&A explicitly marked "contract not suggestion"; reuse table tells exactly where to make a change
- **Trade-off**: +21 lines, volume_efficiency to 0.78
- **Net**: very useful additions but no new gates → small weighted gain

### v3-m5-consolidation (+0.003)
- **What changed**: merges 严格度 table into 8-hats table, marks Output Contract as canonical and cross-refs from RF/Rationalizations, removes standalone "设计哲学" section (moved into Relationship)
- **Strength**: volume_efficiency up (+0.09) — 15 lines shorter than baseline without losing RFs/Q/rationalizations
- **Trade-off**: zero integration gain, slight actionability loss (-0.01) because the "source of truth" note is now embedded as a quote rather than a standalone heading
- **Net**: clean refactor but no functional gain → near-zero weighted delta

## Why no_improvement

The baseline already won round 1 with mature enforcement (RF-1..9 + 5-question Self-Check + honeypot rejection + ALWAYS-FOLLOW marker). Each round-2 mutation targets one quadrant cleanly:
- v1 → completeness (Q&A)
- v2 → integration (payload schema + diagram + fallback)
- v3 → consolidation (volume + cohesion)

None of them simultaneously cover ≥ 2 quadrants, so per-variant delta caps at ~0.02. The +0.05 threshold requires either a brand-new mechanism class (not present) or a hybrid.

## Recommendation

- Status: `no_improvement` — do not promote any variant as round-2 winner
- Suggested round-3 strategy: **hybrid** that absorbs:
  - v2's handoff payload + constitution fallback ordering (the integration / enforcement core)
  - v1's 6 Q&A entries + reuse change-location table (the actionability boost)
  - v3's table-merge + canonical-position cross-references (the volume offset to keep total length manageable)
  - Combined Δ could plausibly clear +0.05 because the v2+v1 gains are additive and v3's consolidation pattern can absorb ~30 lines of the new content
