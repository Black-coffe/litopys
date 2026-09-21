# ADR-002: `bench` drives recall through `claude -p` with a test stub; tokens counted cache-inclusive as one figure

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-0-1

## Context
From `plan.md` `## Assumptions`:
> **Bench drives recall through `claude -p`.** `bin/litopys bench` runs `claude -p --plugin-dir <root> --output-format json "/litopys:recall <question>"` from the host project's cwd, once per question. This is a CLI, not a hook, so a model call is allowed. Tests use a stub `claude` (env `LITOPYS_CLAUDE`) so the suite stays model-free.

From `## Tradeoffs`:
> **Bench via `claude -p` with a stub in tests vs an in-session skill.** Chose the CLI: tokens, cost and duration are in the JSON output, and the run is reproducible from a terminal. Rejected an in-session `/litopys:bench` skill: no clean token count per question, and it would pollute the measuring session.

From contract C5 and its round-1 rationale:
> `tokens_in` = `usage.input_tokens + usage.cache_creation_input_tokens + usage.cache_read_input_tokens` (missing fields count 0) ... Rationale (round 1): `usage.input_tokens` alone is the uncached slice (2 tokens on a probe against 27k cache-creation + 24k cache-read), so a cache-blind column reads 0 on every real row and cannot serve D15's «phases 1-3 must exceed the baseline» or D12's ~5% ceiling.

From `## Plan deltas`:
> 2026-09-21, round 1 -> wave 6: Ask 4's «токены» were not delivered in phase 0 as built (all real rows `tokens_in:0, tokens_out:0`); C5 revised, stories 07 and 08 cut, baseline to be re-run after wave 6 before round 2.

## Options
1. An in-session `/litopys:bench` skill run inside the measuring session - rejected: pollutes the very session being measured, no clean per-question token count.
2. `bin/litopys bench` shelling out to `claude -p --output-format json`, once per question, with a stub `claude` (`LITOPYS_CLAUDE`) for tests - chosen.
3. (token counting) `usage.input_tokens` alone as `tokens_in` - rejected in round 1: reads 0 on every real row because it excludes cache creation/read, which dominates a plugin session's cost.
4. (token counting) Cache-inclusive sum (`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`) folded into one `tokens_in` figure - chosen.

## Decision
`bench` is a CLI that forks a real `claude -p` process per golden question and parses its `--output-format json`. Tests substitute a stub binary via `LITOPYS_CLAUDE` so the suite is model-free. Token accounting treats cache creation and cache read as part of `tokens_in`, summing per-model usage objects when the top-level `usage` is all zero, with `null` only when no usage object exists at all.

## Consequences
Reproducible, terminal-runnable measurement with cost/duration free in the JSON output, at the price of a real model call per bench run (not free, not deterministic in cost). The cache-inclusive `tokens_in` gives one comparable figure across phases for D15's "phases 1-3 must exceed baseline" and D12's ~5% ceiling, but the plugin never reports cache-vs-fresh token split - a future consumer wanting that split must re-derive it from raw `usage` objects, which `bench` discards after summing.

## Invariants created
`bin/litopys bench` output rows keep the C5 shape; `tokens_in` is always the cache-inclusive sum, never `usage.input_tokens` alone. Any future bench/measurement code for phase 2+ that re-measures against this baseline must use the same column definitions or explicitly note the incompatibility.

## Revisit when
Phase 2's comparison needs a cache-vs-fresh split, or `claude -p`'s `--output-format json` usage shape changes.
