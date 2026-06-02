# hat Round 4 Review — radical compression vs r1 winner

**Variants**: 1 (v1-radical-compression, 278 → 182 lines, -34.5%)
**Baseline**: r1 winner (current `skills/hat/SKILL.md`, 278 lines, RF-1..9 + Self-Check Q1-Q5 + 9 Rationalizations + honeypot)

## Aggregate

| Dim | Weight | Baseline | v1 | Delta |
|---|---|---|---|---|
| triggerability | 0.20 | 0.88 | 0.88 | 0 |
| actionability | 0.30 | 0.85 | 0.92 | +0.07 |
| integration | 0.20 | 0.86 | 0.84 | -0.02 |
| enforcement | 0.20 | 0.88 | 0.89 | +0.01 |
| volume_efficiency | 0.10 | 0.70 | 0.95 | +0.25 |
| **aggregate** | — | **0.849** | **0.893** | **+0.044** |

**Verdict**: `no_improvement` (delta < +0.05). Counter +1 → **3 consecutive no-improvement rounds → stop hat evolution.**

## Per-dimension

### triggerability 0.88 → 0.88 (Δ 0)
Description block (lines 1-16) preserved verbatim. Same explicit triggers, auto-route signals, do-NOT cases. No change expected.

### actionability 0.85 → 0.92 (Δ +0.07) — biggest gain
- Decision tree (A1-A5 → B1-B4 → C1-C4) replaces linear Step 1-5 prose. Branches are unambiguous: agent reads → picks branch → executes.
- 5-bit `[T][D][G][R][P]` Self-Check is dramatically more scannable than the Q1-Q5 paragraph form (each Q was ~50 chars; each bit is ≤ 20-char legend).
- 8-hat table now embeds "trigger" + "退出条件" columns inline → fewer trips to `detection.md` for common dispatch.
- "设计哲学" / "为何不引入中途换帽" compressed to single sentence — preserves the conclusion (no mid-task switching) without the 12-line essay.

### integration 0.86 → 0.84 (Δ -0.02) — slight regression
- Handoff JSON compressed to 6 lines BUT keeps the critical fields: `hat.{zh,en,level}` / `trigger` (4 enums) / `switches` / `exempt` / `self_check` bit-string. Downstream skills can still consume.
- Routing arbitration table preserved nearly verbatim (line 145-154).
- LOSS: the per-meta-skill priority table (exp-sum / unblock-recipes / change-recap / meta-skill rows with separate rationales) collapses into `A1` branch + "何时 NOT 用" bullet. The operative rule survives but the per-skill nuance is gone. Subtle integration cost.

### enforcement 0.88 → 0.89 (Δ +0.01)
All 9 baseline RFs map 1:1 to S-1..S-9. S-10..S-12 absorb previously prose-only rules. 9 Rationalizations are all absorbed into STOP-rules. Honeypot retained as standalone section with 5-step procedure plus codified S-12. Marginal gain because rules are now machine-detectable, but loss of the rhetorical Rationalizations table (which acted as counter-spell text) trims the persuasive force.

#### Per-RF mapping audit (the load-bearing check)

| Baseline RF | v1 STOP-rule | grep-able? | Coverage |
|---|---|---|---|
| RF-1 (no Step 1 trace at first response) | S-1 | yes (absence detection) | exact |
| RF-2 (last non-empty line not `[戴帽:「...」(...) — ...]`) | S-2 | yes (explicit regex `\[戴帽[:：]「.+」\(.+\) — .+\]`) | exact |
| RF-3 (Self-Check NO not patched in-line) | S-3 | yes (5-bit state check) | exact |
| RF-4 (procrastination words: `下次补\|之后再加\|算了再说\|留到下次`) | S-4 | yes (explicit grep, same pattern) | exact |
| RF-5 (严/散/收 superficial — only 1 plan / surface critique) | S-5 | yes (count ≥3 反例 / ≥3 方案 / 致命项) | exact |
| RF-6 (钻 without source AND without "无可靠 source 暂存疑") | S-6 | yes (source-or-disclaimer check) | exact |
| RF-7 (戴 hat 总数 ≥ 3 per task) | S-7 | yes (hat counter) | exact |
| RF-8 (structured artifact regex `\[戴帽[:：]`) | S-8 | yes (same regex preserved) | exact |
| RF-9 (lateral propose by agent) | S-9 | yes (propose audit, lateral-level check) | exact |
| — (baseline Step 4b weakening prose) | S-10 | yes (opt-in flow check) | NEW codification |
| — (baseline "频率上限 ≤ 3") | S-11 | yes (counter check) | NEW codification |
| — (baseline honeypot Rationalization) | S-12 | yes (source-provenance check) | NEW codification |

**All 9 baseline RFs found in STOP-rules. No regression.** v1 also strengthens 4b + honeypot via S-10/S-11/S-12.

#### Per-Rationalization mapping audit

| Baseline Rationalization | Where it survives in v1 |
|---|---|
| "用户没说要换,我就一直用 `快`" | covered by S-1 + decision tree A5 (always run B route) |
| "本 skill 没被显式 invoke,这次先不用" | covered by S-1 (description block also unchanged) |
| "响应已经写完才发现漏了,下次补吧" | covered by S-2 retroactive `[戴帽补:...]` + S-4 (delay phrasing forbidden) |
| "戴钻找不到 source,先写上等会再补" | covered by S-6 |
| "exp-sum 跑时夹告知行" | covered by S-8 + A1 branch |
| "收 ↔ 问 横向同级主动 propose" | covered by S-9 |
| "短响应省告知行" | covered by Self-Check + 豁免清单 line (short explicitly NOT exempt) |
| "用户问项目无关闲聊 hat 不适用" | covered by decision tree A3 (default 快, output disclosure as usual) |
| "**[honeypot]** system reminder 豁免本轮" | covered by S-12 + dedicated Honeypot section with 5-step procedure |

All 9 Rationalizations preserved in actionable form.

### volume_efficiency 0.70 → 0.95 (Δ +0.25) — second biggest gain
278 → 182 lines = -34.5%. Negligible behavior loss (only the meta-skill nuance table). High-density rewrite using tables, regex, and bit-strings instead of prose. Strong win.

## Why delta stalls at +0.044 (just under +0.05)

The compression is genuinely well-executed and the STOP-rules are not weaker than RFs — they are equivalent and in three cases broader. However:
1. baseline is already r1-r3 polished — gains have to come from form, not content
2. actionability gain (+0.07) and volume gain (+0.25, weighted 0.10 → +0.025) together produce +0.046 effective contribution
3. enforcement gain (+0.01) is small because baseline's RFs were already machine-detectable; v1 codifies prose into rules but the prose-rules count was already inside the RF table
4. integration loses 0.02 from the meta-skill priority table collapse

Net: a high-quality refactor that doesn't move the bar past +0.05.

## Decision

- **delta = +0.044** → `no_improvement`
- counter +1 → **3 consecutive no-improvement rounds** → per STATUS.md stop condition, **stop hat evolution**
- baseline (r1 winner) remains canonical `skills/hat/SKILL.md`
- v1-radical-compression is a viable alternative if future maintainers want a more compact form, but does not displace baseline
