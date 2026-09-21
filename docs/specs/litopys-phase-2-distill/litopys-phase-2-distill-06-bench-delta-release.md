---
story: litopys-phase-2-distill-06
spec: litopys-phase-2-distill
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 4
blocked_by: [litopys-phase-2-distill-05]
---

# `bench --delta` (C15), bench hardening (Ask 9), version 0.2.0

## Goal
`bash bin/litopys bench --delta` prints the one C15 line comparing the last five rows of `.litopys/baseline.jsonl` with its first five (hits, refs, seconds, tokens_in, tokens_out, cost_usd), without calling `claude`; fewer than ten rows is exit 2. The four phase-0-1 bench findings are closed: the `BENCH_USAGE_JQ` comment says why cache fields are summed (the round-1 zeros), snake_case and camelCase fields are summed per object instead of both at once, an all-zero top-level `usage` with a `modelUsage` fallback is tested, and unparsable `claude` stdout writes its row with an `error` key. The plugin becomes 0.2.0.

## Requirements
> повторный замер золотых вопросов vs baseline; выход: delta vs baseline
> bench: comment wording on the round-1 zeros, snake_case+camelCase summed, no test for all-zero top-level `usage`, unparsable stdout scored as a miss without an `error` key
> a new `bench --delta` prints the latest run against the first five rows of `.litopys/baseline.jsonl` (hits, refs, seconds, tokens) so the phase's exit criterion "delta vs baseline" is one command; the golden questions themselves stay as shipped (D10, D15)

## Files
- bin/litopys
- tests/bench.test.sh
- tests/fixtures/claude-stub.sh
- tests/fixtures/baseline-delta.jsonl
- .claude-plugin/plugin.json
- CHANGELOG.md
- tests/append.test.sh
- tests/hooks.test.sh
- hooks/session-start.sh

## Non-goals
- `--delta` never runs `claude`, never reads `docs/chronicle/golden-questions.md`, never writes a row. It does not compare arbitrary row ranges, take flags for row selection, or compute per-question deltas - five sums, one line.
- Do not change the C5 row keys, the `hit`/`refs_matched` rules, or `examples/vulyk/golden-questions.md`.
- Do not touch `distill`, `append` logic, agents, skills, or `hooks.json`. In `tests/append.test.sh`, `tests/hooks.test.sh` and `hooks/session-start.sh` change **only** a `0.1.0` version literal, if one exists there (recon question 1 in plan.md); if none exists, leave the file untouched.
- Do not restructure `bench`'s existing flow to add `--delta`; it is an early branch in `cmd_bench` (or a `cmd_bench_delta` called from it).
- CHANGELOG `[0.2.0]` lists what this spec shipped, in the `[0.1.0]` section's style; no "Unreleased" section, no future items.

## Map slice
`memory/map/litopys-plugin.md` - Entry points (`bench`), C5 (`BENCH_USAGE_JQ`), Tests and fixtures, Gotchas (cache-inclusive `tokens_in`); `recon/plugin.md` Q2 (`bin/litopys:126-142, 237-243, 278-289`) and Q4 (`claude-stub.sh:21-32, 34-65`); brief.md "Phase-0 baseline to beat"; plan.md C15, `## Assumptions` (0.2.0 bullet).

## Acceptance criteria
- [ ] `tests/fixtures/baseline-delta.jsonl` holds 10 C5 rows (5 baseline, 5 latest) with known sums, one latest row with `tokens_in: null`, plus a second variant (or a generated one) with all-numeric rows.
- [ ] `bench --delta` on the all-numeric fixture prints exactly the C15 line with the expected numbers (hits `4/5 -> 5/5 (+1)`, refs fractions, seconds, integer percentages, `(+0)`/`(0%)` where equal) and exits 0; on the null-variant `tokens_in null -> ... (n/a)`; on a 9-row file exits 2 with one stderr line and no stdout; no `claude` call happens (`LITOPYS_CLAUDE` pointing at a script that exits 99 does not run).
- [ ] `BENCH_USAGE_JQ`'s comment explains that `usage.input_tokens` alone is the uncached slice and read 0 on every real row in round 1, hence the cache fields are summed.
- [ ] A `usage` object with both `input_tokens` and `inputTokens` present counts each field once (per-object preference: snake if present, else camel) - a test asserts no double count.
- [ ] A stub payload with top-level `usage` all zero and a populated `modelUsage` yields `tokens_in`/`tokens_out` from `modelUsage` (a test names this case explicitly, even if a fixture already exercised it).
- [ ] The stub gains a case that prints non-JSON stdout with exit 0; the row for it has `hit:false`, `refs_matched:0`, `tokens_in:null`, and `"error":"unparsable stdout"`; the summary line still counts it as a miss.
- [ ] `bin/litopys --version` prints `0.2.0`; `.claude-plugin/plugin.json` `version` is `0.2.0`; every test asserting the version passes; `distill.jsonl` and C5 rows carry `"litopys":"0.2.0"`; `CHANGELOG.md` has a `[0.2.0]` section naming distill record/next/finish, the `PreCompact` marker, banner line 4, the `distiller` agent, redactor fallback, `--ref` normalisation, `bench --delta`.
- [ ] Every file LF; `jq -e . .claude-plugin/plugin.json` passes; `bash -n bin/litopys` clean.

## Verification
`bash tests/bench.test.sh`

## Implementation notes

## Findings
