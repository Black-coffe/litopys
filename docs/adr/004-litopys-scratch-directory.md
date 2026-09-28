# ADR-004: `.litopys/` as the plugin's self-ignoring per-project scratch directory

- Status: proposed; superseded in part by ADR-010 (v0.3.0) - the plugin now writes one managed block
  into the host's `.gitignore`, so the invariant "no plugin code writes to a host's `.gitignore`" no
  longer holds; the self-ignoring `.litopys/` stays as the second fence
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-0-1

## Context
From `plan.md` `## Assumptions`:
> **`.litopys/` self-ignores.** Every writer creates `.litopys/.gitignore` containing `*` on first write, so no host project's `.gitignore` or CLAUDE.md is touched. The litopys repo's own `.gitignore` also lists `.litopys/`.

And contract C1:
> **C1 - project root and `.litopys/` dir (every story).** Root = `$CLAUDE_PROJECT_DIR` if a directory, else payload `cwd` (hooks), else `git rev-parse --show-toplevel`, else `$PWD`. Any writer of `.litopys/` first runs `mkdir -p .litopys && [ -f .litopys/.gitignore ] || printf '*\n' > .litopys/.gitignore`.

The self-ignore mechanism reads directly on Ask 7's «ничего не пишется в CLAUDE.md» (`## Assumptions`, last bullet): the plugin must never touch a host's own git-ignore or constitution files.

## Options
None recorded - the plan states the chosen shape (a self-ignoring `.litopys/` created lazily by whichever writer touches it first) without listing alternative locations or mechanisms that were weighed.

## Decision
Every host project gets one plugin-owned directory, `.litopys/`, at its root. Any code that writes into it first ensures `.litopys/.gitignore` contains `*`, so the directory never needs an entry in the host's own `.gitignore` or any mention in the host's `CLAUDE.md`. Root resolution follows a fixed fallback chain (`$CLAUDE_PROJECT_DIR` -> hook payload `cwd` -> `git rev-parse --show-toplevel` -> `$PWD`).

## Consequences
The plugin can write baseline data (`.litopys/baseline.jsonl`) and raw journals (`.litopys/raw/*.md`) into any host without a setup step or a host-side edit, satisfying the "nothing writes to CLAUDE.md" constraint outright rather than by convention. The cost is a directory that self-manages its own git-ignore idempotently on every write path (`[ -f .litopys/.gitignore ] || printf '*\n' > .litopys/.gitignore`) - any new writer of `.litopys/` must repeat this line or the invariant silently breaks for that writer.

## Invariants created
Nothing under `.litopys/` ever enters git in a host project. No plugin code writes to a host's `.gitignore` or `CLAUDE.md`. Root resolution for any script uses the C1 fallback chain, in that order.

## Revisit when
A phase-2 distiller needs to persist consolidated output *into* the host's tracked tree (e.g. `docs/chronicle/`) rather than the scratch directory - that is a different write path and does not reuse `.litopys/`'s self-ignore.
