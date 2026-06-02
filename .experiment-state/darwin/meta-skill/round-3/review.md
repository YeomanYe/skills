# meta-skill r3 review — v1-integration-plus-compression vs r2 baseline

## Verdict

- **baseline (r2 winner)**: aggregate 0.881
- **v1-integration-plus-compression**: aggregate 0.900
- **delta**: +0.019
- **status**: `no_improvement` (0 ≤ delta < +0.05)
- **winner**: v1-integration-plus-compression (only candidate; still kept as new source)

## Scoring (5 dim)

| Dim | Baseline | v1 | Delta | Note |
|---|---|---|---|---|
| triggerability | 0.85 | 0.85 | 0 | description frontmatter unchanged (lines 1-14 identical) |
| actionability | 0.90 | 0.91 | +0.01 | 7 Workflow steps preserved; edge cases now scannable as 6-row table |
| integration | 0.92 | 0.97 | +0.05 | **mutation target hit**: new Why-Keep-It section + keep-rule:<id> cite + sync-skills + skill-doctor contracts |
| enforcement | 0.91 | 0.92 | +0.01 | 15 Red Flags (target ≥12), 8 Rationalizations, Self-Check 5Q + 8 High-Risk Actions intact; keep-rule cite adds enforcement teeth |
| volume_efficiency | 0.75 | 0.85 | +0.10 | 285 → 259 lines (-9.1%, beats -8% target); edge cases table, tighter prose, single-line Output/Reuse |
| **aggregate** | **0.881** | **0.900** | **+0.019** | below +0.05 improved threshold |

## Invariant preservation check (vs baseline)

| Check | Present? | Where |
|---|---|---|
| Pre-action Self-Check 5-Q | yes | lines 128-132 |
| 8 High-Risk Actions | yes (all 8) | lines 49-56 |
| Inline Manifest Schema | yes | lines 92-116 |
| 4-command contract | yes | lines 172-175 |
| exp-sum signal schema | yes | lines 194-202 |
| ASCII flow | yes (compressed) | lines 28-37 |
| Rationalizations 8 | yes (all 8 rows) | lines 242-249 |
| Red Flags ≥12 | yes (15) | lines 218-232 |

## Mutation deltas (vs baseline)

### Integration ↑↑ (mutation target)

1. **New "Why-Keep-It" section** (lines 180-188) — codifies that any rationale touching `hat` / `experience-summary` / `unblock-recipes` must cite `keep-rule:hat-001` / `keep-rule:exp-sum-001` / `keep-rule:unblock-001` in `rationale[].reason`. Stronger than baseline's "just don't disable them" — manifest now leaves an audit trail.
2. **New sync-skills contract** (line 209) — explicit "本 skill 不调用 sync-skills, missing skill 必须 surface 给 user, sync 是 user gesture". Closes a gap baseline left implicit.
3. **New skill-doctor contract** (line 210) — assumes orchestrator pre-pass; if `list-available` reports `disabled-by-doctor`, candidate excluded with `rationale: excluded: doctor-flag`. New cross-skill contract.

### Volume ↓ (mutation target)

- 5 prose edge cases (Step 1.0 in baseline) → 6-row Edge Cases table (lines 156-163). More scannable, less duplication.
- ASCII flow tightened from 17 lines → 10 lines.
- Step 1 A/B/C/D blocks collapsed from multi-line per item to single-line per item.
- Cross-Skill Boundaries Sibling block folded into Why-Keep-It (deduped with keep section).
- Output Contract collapsed to one line; Reuse collapsed to one line.

## Verdict rationale

The variant genuinely advances integration (its primary target) — Why-Keep-It with cite IDs is a structural improvement, and sync-skills / skill-doctor contracts close real gaps. Volume efficiency cut is real (-9.1%) without losing any invariants. But the gains are concentrated in 2 of 5 dimensions (integration, volume) while the other 3 are flat-to-slightly-up. Aggregate +0.019 lands in the `no_improvement` band (< +0.05).

Recommend keeping v1 as the new source even at `no_improvement` because: (1) it dominates baseline on every dim (no regressions), (2) the new contracts are load-bearing for downstream agents, (3) compression is genuine signal-preserving. Future rounds should look for triggerability / enforcement levers since integration and volume are now near-saturated.
