---
story: litopys-phase-0-1-09
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 7
blocked_by: [litopys-phase-0-1-06]
---

# Fix round 2 / Ask 6: every `## Losses` item checkable in the journal and the `/export` file

## Goal
After this story `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` still names what the raw journal loses on session `a10ea931`, but every numbered item under `## Losses` is checkable in exactly the two files the ask names - the journal `E:/Projects/vulyk/.litopys/raw/a10ea931-a24f-4942-aa20-743c4eeb9e4a.md` and the export `E:/Projects/vulyk/.litopys/export-a10ea931.md`. Review round 2 major 5 (carried from round 1 major 6): Loss 3 and most of Loss 4 are sourced from `export-a10ea931.md.pty.log`, a terminal capture that is neither the journal nor `/export`; Losses 5 and 6 grep the pty log as well. Those observations move to a clearly separate section outside the comparison, and the deviation is recorded.

## Requirements
> Проверка на одной реальной сессии VULYK ≥100k токенов: сырой журнал сравнивается с `/export` той же сессии; отчёт `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` называет, что журнал теряет.

## Files
- docs/specs/litopys-phase-0-1/recon/raw-vs-export.md

## Non-goals
- Do not re-run any session, re-export, or touch anything under `E:/Projects/vulyk/.litopys/`; the two input files and the pty log are read-only evidence.
- Do not fix the hooks or the journal format, and do not extend the `## Verdict` list beyond its three items.
- Do not delete the pty-log observations - they stay in the report, in their own section, labelled as outside the ask's comparison.
- Do not paste large slices of either file; keep the existing quote-a-few-lines discipline.

## Map slice
Contract C8 in plan.md (what the journal is defined to hold). Story 06 acceptance criteria 2 and 5 (each loss cites one example; every claim is a `grep` pattern or block header lookable up in the two files). Review round 2 `council/round-2/review.md` major 5.

## Acceptance criteria
- [ ] Under `## Losses`, every numbered item cites its evidence only from the journal or the export file (a `grep` pattern or a line/block reference in one of those two); no item mentions the pty log or any third file.
- [ ] Loss 3 (slash-command expansions) and Loss 4 (terminal session metadata) are either re-grounded in the export file itself - if `export-a10ea931.md` actually contains the command text or banner, cite the line - or moved out of `## Losses`.
- [ ] Losses 5 and 6 (compaction, subagent output) keep their "checked, not applicable" status but their `grep` lines run only over the two named files.
- [ ] A new section `## Outside the comparison (pty log)` after `## Kept` holds every observation sourced from `export-a10ea931.md.pty.log`, opens with one sentence saying these are terminal-capture facts the ask did not name and phase 2 may or may not weigh them, and cites `pty.log` line numbers or literal markers.
- [ ] `## Header` gains one line naming the pty log as a sidecar that exists but is not one of the two compared files.
- [ ] `## Verdict` still reads correctly after the move: any sentence that leaned on a pty-only loss (the "slash-command/session-control layer" clause) is reworded to lean on the export file or is attributed to the new section explicitly.
- [ ] Implementation notes list, per moved or reworded item, old placement -> new placement and why, so the Queen can audit before round 3.

## Verification
`test -s docs/specs/litopys-phase-0-1/recon/raw-vs-export.md && grep -q '^## Losses' docs/specs/litopys-phase-0-1/recon/raw-vs-export.md && grep -q '^## Verdict' docs/specs/litopys-phase-0-1/recon/raw-vs-export.md && grep -q '^## Outside the comparison' docs/specs/litopys-phase-0-1/recon/raw-vs-export.md && ! awk '/^## Losses/{f=1;next} /^## /{f=0} f' docs/specs/litopys-phase-0-1/recon/raw-vs-export.md | grep -qi 'pty'`

## Implementation notes

- File touched: `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md`.
- `## Header` -> added a line naming `export-a10ea931.md.pty.log` as a sidecar that exists but is not one of the two compared files.
- Old Loss 3 (slash-command expansions, `/export`/`/exit` text) -> moved to `## Outside the comparison (pty log)` item 1: `grep -c '/export\|/exit'` against the journal and export.md returns 0 in both, so nothing in the ask's two files supports this claim; only the pty log has it.
- Old Loss 4 (session/environment metadata) -> split: the static startup banner (`Claude Code v2.1.278`, `Sonnet 5 · Claude Max`, cwd) *is* present in `export-a10ea931.md` lines 1-3, so it stays in `## Losses` (renumbered to item 3) re-grounded on the export file itself, not the pty log. The live readouts (resume hint, effort indicator, permission-mode banner, context-usage) are pty-log-only -> moved to `## Outside the comparison (pty log)` item 2.
- Old Losses 5 and 6 (compaction, subagent) -> kept in `## Losses` (renumbered 4 and 5), their `grep` commands rewritten to run only over the journal and `export-a10ea931.md`, dropping `export-a10ea931.md.pty.log` from the pattern; both greps still return no hits, so the "checked, not applicable" verdict is unchanged.
- `## Kept` item 3 -> reworded: it previously cited "the export's resume hint" as matching the journal's cwd, but the resume hint only exists in the pty log. Repointed to the export's own static banner line 3 instead.
- `## Kept` item 4 -> reworded "matching export's `/exit`" (pty-log-only) to "matching the last user turn recorded in the export" (export.md itself has no `/exit` trace either).
- `## Verdict` -> the "slash-command/session-control layer is invisible" clause is now attributed explicitly to the new `## Outside the comparison` section rather than folded into the journal-vs-export claim; the numbered phase-2 list still has exactly three items, #3 reworded to note the two named files carry none of that text today.

## Findings
