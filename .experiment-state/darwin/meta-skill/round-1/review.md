# Round-1 Review — meta-skill

Reviewer: single-reviewer darwin evolution
Dimensions: triggerability (0.20) / actionability (0.30) / integration (0.20) / enforcement (0.20) / volume_efficiency (0.10)
Threshold: winner must score >= baseline + 0.05 to count as "improved".

## Score Summary

| File | Trig | Act | Int | Enf | Vol | Weighted |
|---|---|---|---|---|---|---|
| baseline (192 ln) | 0.85 | 0.75 | 0.75 | 0.72 | 0.85 | **0.77** |
| v1-m1-clarity (175 ln) | 0.85 | 0.76 | 0.73 | 0.71 | 0.90 | **0.78** |
| v2-m2-completeness (248 ln) | 0.86 | 0.82 | 0.78 | 0.79 | 0.80 | **0.81** |
| v3-m3-integration (260 ln) | 0.85 | 0.84 | 0.93 | 0.78 | 0.78 | **0.84** |
| **v4-m4-enforcement (241 ln)** | 0.86 | 0.86 | 0.77 | 0.92 | 0.81 | **0.85** |

## Per-Variant Summary

### baseline (0.77)
Solid foundation: full frontmatter triggers (auto / explicit / upstream / Do-NOT), 6 numbered steps with sub-letters for probe (A-D), 4-stage skill matrix table, user-gate prose, Red Flags ×7, Rationalizations ×4. No formal pre-action self-check; no monorepo / submodule / corrupt handling; integration via prose sections without JSON schemas or contract commands.

### v1-m1-clarity (0.78)
Compresses prose into tables (When to Use / NOT merged, tech-stack table, stage table) and trims sub-prose. Saves 17 lines (volume_efficiency 0.90). No new gates, schemas, or contracts. Net weighted lift basically flat — clarity gain offset by lost emphasis repetition in Red Flags.

### v2-m2-completeness (0.81)
Materially expands coverage:
- Step 1.0 boundary detection (project root walk-up / submodule vs nested / monorepo signals: pnpm-workspace.yaml / lerna.json / nx.json / turbo.json / Cargo workspace)
- Step 2.5 monorepo branching (union manifest for root + per-package manifests; sub-package disable wins; enable > 12 → user picks main stack)
- Step 3 corrupt manifest path (backup to `.broken.<timestamp>`, never silent overwrite)
- Step 4 opt-out branch (write empty `enable: []` + `user_opt_out: true`)
- Step 7 auto-re-review with 7-day cooldown
- Q&A ×6, Red Flags 7 → 9, Rationalizations 4 → 6
Strengthens actionability (0.82) and enforcement (0.79) by closing real ambiguity gaps. Still no formal pre-action self-check or contract schemas.

### v3-m3-integration (0.84)
Strongest integration layer of any variant:
- ASCII end-to-end flow diagram (cwd change → probe → manifest → user-gate → apply → halt)
- Full inline Manifest JSON Schema with field-level constraints (`enable ∩ disable = ∅`; `enable[i] ∈ skillshare list-available`; `rationale` covers `enable ∪ disable`; `signals[] >= 1`)
- "Integration with skillshare" section: 4 contract commands (`list-available` / `status` / `apply` / `revert`) + invariants ("apply reads enable/disable/keep; errors must surface; never bypass enabled.txt")
- "Cross-Skill Boundaries" section: exp-sum signal JSON schema (`trigger / from / to / evidence / confidence`) with `confidence < 0.6 → stricter user gate`; flow-skill-research input/output contract with "research = idea, meta-skill = manifest" separation
- 1 extra rationalization (exp-sum confidence=0.95 does NOT skip gate)
Actionability also improved (0.84) via inline schema + concrete commands. Loses to v4 only because enforcement layer is baseline+1 rationalization, not coded gates.

### v4-m4-enforcement (0.85) — WINNER
Strongest on the two heaviest-weighted dimensions:
- **Actionability 0.86**: dedicated "High-Risk Actions — 必经 User Gate" section listing 8 specific actions that require the gate (skillshare enable/disable, write enabled.txt, overwrite existing manifest, disable user-managed skills, reset user-edited fields, post-research auto-enable, low-confidence stage auto-apply, fake applied_at). New "Pre-action Self-Check" with 5 ordered yes/no questions enforced before the gate, plus an explicit "modify X → re-run self-check → re-gate, never direct apply" loop and a Step 6 halt that records skip choices to avoid skip-loops.
- **Enforcement 0.92**: Red Flags expanded from 7 to 12 with new codes for "signals[] missing source/evidence/implies" / "stage.confidence missing" / "user-managed skills written to disable[]" / "self-check bypass" / "GC user-edited fields". Rationalizations grow from 4 to 8 with targeted evasion-path rejections: fake "always apply" standing order, "skip confidence field for cleanliness", "skipping list-available because I've seen these before", "delete user's outdated notes". read-only vs high-risk split is explicit; probe results MUST land in `signals[].evidence`.
- **Integration 0.77**: marginal gain only — adds "user-managed skills always excluded from enable/disable" and "flow-skill-research result still requires user gate" but no JSON schemas or command contracts.
- **Volume 0.81**: 241 lines — leanest of the three "completeness/integration/enforcement" variants.

Trade-off: did not adopt v3's manifest schema or skillshare command contract. A round-2 merge of v4's enforcement layer with v3's integration layer is the natural next step.

## Winner Decision

**Winner: v4-m4-enforcement** (weighted_avg 0.85)
**Baseline: 0.77** — **delta +0.08** — **improved** (>= +0.05 threshold)

### Rationale
v4 wins because the rubric weights actionability (0.30) + enforcement (0.20) = 50% of the total, and v4 dominates both. The Pre-action Self-Check 5-question gate converts an abstract "user gate" into an executable checklist; the High-Risk Actions enumeration removes ambiguity about which steps require the gate; the expanded Red Flags + Rationalizations attack the specific drift paths a long-lived config-generating skill faces (cached trust, confidence-skip, list-available skip, GC of user-edited fields). v3 was a very close runner-up at 0.84 with the strongest integration layer (inline Manifest JSON Schema, skillshare 4-command contract block, exp-sum signal JSON schema, flow-skill-research I/O contract, ASCII flow diagram) — its enforcement layer is the limiter. v2 added valuable edge-case coverage (monorepo / submodule / corrupt / opt-out / 7-day cooldown) but lacks both v3's contract schemas and v4's enforcement codes. v1's compression yields a small volume gain with no behavioral lift.

### Recommended Follow-up (out of scope this round)
Round-2 candidate: merge v4's High-Risk Actions + Pre-action Self-Check + expanded coded Red Flags with v3's inline Manifest JSON Schema + skillshare command contract + exp-sum signal schema + flow-skill-research I/O contract. Also pull in v2's Step 1.0 boundary detection + Step 2.5 monorepo branching + Step 3 corrupt path. Target: integration ~0.90, enforcement ~0.92, actionability ~0.87, while keeping volume under ~280 lines by moving the manifest schema and skillshare command block into a referenced sidecar file.
