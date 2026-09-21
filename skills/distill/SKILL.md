---
name: distill
description: Turns closed raw session journals under .litopys/raw/ into git-tracked session records in docs/chronicle/sessions/. Trigger with /litopys:distill to distill pending journals and commit the chronicle.
context: fork
agent: distiller
allowed-tools: Read, Write, Grep, Glob, Bash
---

# `/litopys:distill`

Arguments: `$ARGUMENTS`

Distill the raw session journals that are waiting in `.litopys/raw/`. You run in a forked
context: only your final report reaches the caller, never the journals you read.

If `$ARGUMENTS` is non-empty it is a number, and it is passed to `distill next` as `--max
$ARGUMENTS` - nothing else. Empty arguments mean the CLI's own default (3).

Follow the procedure in the `distiller` agent exactly: `distill next` to claim the queue,
then per journal read / write a body / `distill record` / delete the body, then
`distill finish`. The CLI owns the queue, the lock, the record, the chronicle line and the
commit; you only read journals and write body files.

## Return

Return only:
```
**Distilled:** <n> session(s)
- docs/chronicle/sessions/<file> - <title>
**Skipped:** <s> (bench/recall journals -> .litopys/raw/skipped/)
**Commit:** <sha7> | uncommitted: <reason> | locked
**Pending:** <p> journal(s) remain
```
