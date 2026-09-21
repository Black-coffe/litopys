# ADR-008: Distill queue - mkdir lock, N=3 oldest-first cap, first-line skip rule, done/skipped layout

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-2-distill

## Context
From `plan.md` `## Assumptions`:
> **N=3 per run, oldest first** (Answer 4); the skip rule runs over the whole *eligible* backlog before the cap, so one run clears every closed bench journal. A journal whose session may still be running is never moved (wave 5).
> **A distilled journal moves to `.litopys/raw/done/<sid>.md`** (kept indefinitely, gitignored, re-distillable with `--force`), so "pending" is simply what is left at the top level. Rejected: a `.distilled` marker file per journal - a second thing to keep in sync.
> **Eligibility:** `distill next` offers a journal only if its last `## ` block is `## closed`, or its mtime is older than 60 minutes (a crashed session never gets `## closed`).

And C12: "`mkdir` lock, 30-min stale... skip rule -> `skipped/`... cap N=3 oldest first"; amended by `## Plan deltas` (review round 1 critical 1): the skip rule only runs over journals that already pass eligibility, and a journal with no `## user` block is skipped, not distilled, because a session that produced no user turn yet may still be running.

## Options
none recorded - the delta states the chosen shape only.

## Decision
`bin/litopys distill next` uses a `mkdir`-based lock (`.litopys/distill.lock`, 30-minute staleness) to serialize queue access; classifies each top-level journal as eligible (last block `## closed`, or mtime > 60 min) before anything else; over eligible journals only, skips into `.litopys/raw/skipped/` any whose first `## user` block starts with `/litopys:recall` or `/litopys:distill`, or that has no `## user` block at all; caps the remaining offer at N=3, oldest-first by frontmatter `started`. Distilled journals move to `.litopys/raw/done/<sid>.md` (kept, gitignored, re-distillable with `--force`) rather than gaining a marker file.

## Consequences
A journal whose session may still be running (no user block yet, or too fresh) is never moved by any code path, closing off a race between a live session and a distill run. One run clears the entire eligible backlog's bench/recall noise regardless of N, since the skip rule runs before the cap. The cost: two directories to reason about (`done/`, `skipped/`) plus a lock directory, and eligibility/skip logic that must stay in this exact order or the critical-1 bug (a running session's own journal skipped mid-session) reappears.

## Invariants created
Skip/park decisions in `distill next` run only over journals that have already passed the eligibility check; a journal without any `## user` block is never distilled or moved into `done/`. The N cap applies after skip/park, never before.

## Revisit when
Eligibility or skip logic changes shape (e.g., a new journal kind, a different crash-detection signal), or the 60-minute/30-minute constants prove wrong in practice.
