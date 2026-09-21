# ADR-006: Distillation is skill-driven; no hook ever calls a model

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-2-distill

## Context
From `plan.md` `## Assumptions`:
> **Distillation is skill-driven, never background** (Answer 2): no hook starts a model, spawns `claude -p`, or forks anything; SessionStart only counts. PreCompact only appends a marker. This is the letter of Ask 10.

And CLAUDE.md `## Profile` already states the constraint this decision satisfies: "no model calls inside hooks (deferred to skills/agents)".

## Options
none recorded - the delta states the chosen shape only.

## Decision
Hooks (`SessionStart`, `PreCompact`, `SessionEnd`) never invoke a model, a CLI wrapper (`claude -p`), or fork any process. `SessionStart` only counts pending journals for the banner; `PreCompact` only appends a `## compact` marker line to the current journal (C13). All model work — reading journals, writing the distilled body — happens inside the `/litopys:distill` skill, forked into the `distiller` agent, invoked explicitly by the user or by a future scheduler outside the hook system.

## Consequences
Hooks stay fast, deterministic, and safely runnable inside Claude Code's own hook timeouts without risking a runaway or recursive model invocation. The cost is that distillation cannot happen automatically in the background — a journal sits pending until something (the user, `/litopys:distill`) triggers the skill. This is an accepted tradeoff, not a bug.

## Invariants created
No file under `hooks/` may spawn `claude`, a model process, or any subprocess that itself could invoke one. Any future hook-driven feature must route model work through a skill/agent fork instead.

## Revisit when
A future phase proposes background/scheduled distillation (e.g., via an OS-level cron or a Claude Code scheduled hook) that would need to relax this constraint - re-open only alongside a change to Ask 10 or the host's hook-timeout budget.
