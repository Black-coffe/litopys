# ADR-001: Golden questions authored in the plugin repo, copied to the host at the baseline gate

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-0-1

## Context
From `plan.md` `## Assumptions`:
> **Golden questions are authored in this repo** at `examples/vulyk/golden-questions.md` (story 03 reads E:/Projects/vulyk read-only) and copied by the owner to `E:/Projects/vulyk/docs/chronicle/golden-questions.md` at the baseline gate, because `bench` reads the host project's `docs/chronicle/`. Keeps every story's diff inside this repo (scope-check, Law 3).

And from `## Tradeoffs`:
> **Golden questions authored in litopys vs written straight into the VULYK repo.** Chose authoring in `examples/vulyk/` and a copy at the baseline gate: every story diff stays in this repo, so scope-check and Law 3 hold. `bench` keeps one rule (read the host project's `docs/chronicle/`). Rejected a cross-repo write: the scope gate would see an empty diff and the Queen would commit story output by hand.

## Options
1. Author golden questions directly in the host project's repo (VULYK) - `bench`'s single rule holds, but every story diff would be empty in litopys, defeating scope-check and Law 3.
2. Author in `examples/<host>/golden-questions.md` inside the plugin repo, copied by the owner to the host at the baseline gate - chosen.

## Decision
Golden-question files live under `examples/<host>/` in the plugin repo. The owner copies the finished file to `<host>/docs/chronicle/golden-questions.md` as a manual step at the baseline gate (and again after any correction wave). `bench` only ever reads the host's `docs/chronicle/`.

## Consequences
Every future host onboarding (a second `examples/<host>/`) repeats this same author-then-copy step; nothing in the plugin writes across repos. `bench`'s read path never branches. The copy step is a Queen/owner terminal action, not automated - a phase-2 `/litopys:bench-init` skill (noted as descoped) could remove it.

## Invariants created
No plugin code (CLI, skill, hook) writes files into a host project's repo outside `.litopys/` and `docs/chronicle/` via `append`. Question-authoring content for any host stays under `examples/<host>/` in this repo.

## Revisit when
A phase-2 `/litopys:bench-init` or similar automation is proposed to remove the manual copy step, or a second host project's golden-question set is added.
