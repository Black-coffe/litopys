# ADR-003: Separate hook scripts, not events routed through `bin/litopys`

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-0-1

## Context
From `plan.md` `## Tradeoffs`:
> **Separate hook scripts vs routing every event through `bin/litopys hook <event>`.** Chose separate scripts under `hooks/`: `bin/litopys` stays a user CLI with stdin free (VULYK's "hook modes read stdin, manual modes must not" bug). Rejected the single entry point - one file, but a CLI that sometimes blocks on stdin.

## Options
1. Single entry point - all hook events dispatch through `bin/litopys hook <event>`, reading the event payload from stdin. Rejected: makes `bin/litopys` a CLI that sometimes blocks on stdin depending on invocation context, reproducing a known VULYK bug where hook-mode invocations read stdin but manual invocations must not.
2. Separate scripts under `hooks/` (`raw-journal.sh`, `session-start.sh`), wired via `hooks/hooks.json`, each reading stdin unconditionally because they are only ever invoked as hooks - chosen.

## Decision
Hook logic lives in dedicated scripts under `hooks/`, never inside `bin/litopys`. `bin/litopys` remains a plain user-invoked CLI (`append`, `bench`) with no stdin-reading code path.

## Consequences
Two code locations to maintain (`bin/` for CLI, `hooks/` for hooks) instead of one, but no ambiguity about whether stdin is being consumed on any given invocation - eliminates the class of bug VULYK already hit. Any new hook event added later follows the same pattern: a new script under `hooks/`, wired in `hooks/hooks.json`, never a new subcommand of `bin/litopys`.

## Invariants created
`bin/litopys` never reads stdin. Any Claude Code hook event the plugin responds to gets its own script under `hooks/`, registered in `hooks/hooks.json`.

## Revisit when
A future story proposes adding a new CLI subcommand that also needs to run as a hook, or proposes consolidating hook scripts for shared logic - factor shared logic into a sourced library, not a merge into `bin/litopys`.
