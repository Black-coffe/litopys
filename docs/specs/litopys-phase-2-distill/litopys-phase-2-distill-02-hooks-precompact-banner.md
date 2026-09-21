---
story: litopys-phase-2-distill-02
spec: litopys-phase-2-distill
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 1
blocked_by: []
---

# Hooks: `PreCompact` marker block and the "pending" banner line

## Goal
A fifth hook event exists: `PreCompact` runs `raw-journal.sh compact`, which appends `## compact · <ts> · <compaction_trigger>` (payload field `compaction_trigger`, read as `.compaction_trigger // .trigger // "-"`) to an already-open journal (C8 amended / C13). The SessionStart banner's line 4 becomes the distillation queue line of C9 (amended): `[litopys] distill: <n> pending · run /litopys:distill` or `[litopys] distill: nothing pending`, where `n` counts top-level `.litopys/raw/*.md` only. Still exactly five lines, still no model call, SessionEnd still one `>>` under one second.

## Requirements
> PreCompact-блок
> a `/litopys:distill` skill with `context: fork` and a sonnet `distiller` agent does the work; the SessionStart hook only counts journals awaiting distillation and, past a threshold, says so in the banner (line 4 repurposed, still five lines, D6/D7); a new `PreCompact` hook appends a `## compact · <ts>` marker to the raw journal so the distiller knows a compaction happened (D11)
> никаких вызовов claude -p или модели внутри хуков; SessionEnd-хук укладывается в 1 секунду; ничего не пишется в CLAUDE.md ни одного проекта; только sonnet для агента recall; всё, что идёт в git, проходит scripts/redact.sh

## Files
- hooks/hooks.json
- hooks/raw-journal.sh
- hooks/session-start.sh
- tests/hooks.test.sh

## Non-goals
- Do not start, spawn, fork or `claude -p` anything from any hook; the banner only counts. No "auto-distill past N" logic.
- Do not modify `journal_end()` - add a separate `journal_compact()` with the same `[ -f "$file" ] || return 0` guard and one `>>`; the existing "exactly one `>>` in `journal_end()`" assertion must keep passing as written.
- Do not add a sixth banner line, change lines 1-3 or 5, or touch the jq-less fallback line.
- Do not count `.litopys/raw/done/` or `.litopys/raw/skipped/` (C12 layout - create nothing there either; that is story 04's job).
- Do not add a `timeout` to SessionEnd or change any existing timeout.
- Do not touch `bin/litopys`, `tests/distill.test.sh`, or the version literal (story 06 owns 0.2.0; see recon question 1 in the plan - if line 1 hardcodes `v0.1.0`, leave it).

## Map slice
`memory/map/litopys-plugin.md` - Hooks, C7/C8/C9, Gotchas (one `>>`, five lines); `recon/plugin.md` Q1 (`hooks.json:2-5`, `raw-journal.sh:55-58, 88-93`, `session-start.sh:46, 56-59`, `tests/hooks.test.sh:58-61, 122-123, 152`); plan.md C7/C8/C9 amendments and C13.

## Acceptance criteria
- [ ] `hooks/hooks.json` has exactly five event keys; `PreCompact` -> `bash "${CLAUDE_PLUGIN_ROOT}/hooks/raw-journal.sh" compact` with `timeout` 10; `jq -e .` passes; SessionEnd still has no `timeout`.
- [ ] `printf '{"session_id":"s1","cwd":"%s","compaction_trigger":"auto"}' "$P" | LITOPYS_NOW=... bash hooks/raw-journal.sh compact` on an existing journal appends exactly `\n## compact · <ts> · auto\n`; with no `trigger` field the third field is `-`; on a session with no journal file it creates nothing and exits 0.
- [ ] After `end` then a further `prompt` on the same session, the journal holds `## closed` followed by a new `## user` block, and the test asserts that order (resume-after-close is now a tested behaviour, C13).
- [ ] Banner with two top-level journals plus one file in `.litopys/raw/done/`: line 4 is `[litopys] distill: 2 pending · run /litopys:distill`; with none: `[litopys] distill: nothing pending`; the banner is still exactly five `[litopys]` lines and the JSON envelope is unchanged.
- [ ] Any existing assertion on the old line-4 text is updated; the SessionEnd `end` timing assertion (under one second) still passes.
- [ ] Every file LF; no hook prints to stdout except the SessionStart JSON; every failure path exits 0.

## Verification
`bash tests/hooks.test.sh`

## Implementation notes
- `hooks/hooks.json`: added `PreCompact` -> `raw-journal.sh compact` with `timeout` 10; five event keys now.
- `hooks/raw-journal.sh`: added `compact` to the mode allowlist and a separate `journal_compact()` (same `[ -f "$file" ] || return 0` guard, one `>>`, unaffected `journal_end()`); dispatch case reads `.compaction_trigger // .trigger // "-"` directly from the payload (not via `field()`, since `field` returns empty rather than chaining the second fallback key).
- `hooks/session-start.sh`: line 4 is now `distill_line`, computed from the existing `raws` count (`count_md` already only globs `*.md` directly in the dir, so `done/`/`skipped/` subdirectories were never counted - no change needed there).
- `tests/hooks.test.sh`: added `PreCompact` to the wiring loop + a `hooks.json has exactly five event keys` assertion; added compact-mode tests (marker with trigger, dash fallback, no-op with no journal); added a resume-after-close ordering assertion (C13); changed the banner journal fixture to 2 top-level files + 1 in `done/` and updated line-4 expectations to the new distill text; added `compact` to the fail-open mode loop.

## Findings
