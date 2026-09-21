---
domain: chronicle-format
tags: [litopys, chronicle, journal]
related: [memory/map/litopys-plugin.md]
last-verified: 2026-09-21
---

# Chronicle line format (C3) and raw-journal file format (C8)

Two on-disk formats `bin/litopys` and `hooks/raw-journal.sh` write in a host project. Both are
model-free and append-only. Source: `bin/litopys` `cmd_append()` and `hooks/raw-journal.sh`
(spec `litopys-phase-0-1`, v0.1.0).

## C3 - chronicle line (`bin/litopys append`)

File: `<project-root>/docs/chronicle/YYYY-MM.md`, one file per calendar month (UTC), created
with a `# Chronicle YYYY-MM\n\n` header on first write.

Line shape:
```
- <ISO-8601 UTC timestamp> · <kind> · <ref> · <note>
```
- `<kind>` is one of `grill brief verdict ship handoff note` - any other value is rejected
  (`append` exits 2, nothing written).
- `<ref>` is a path or a sha, required, never redacted.
- `<note>` is optional free text: newlines/carriage-returns/tabs collapse to single spaces
  before it is written, so one record is always exactly one line. When
  `<project-root>/scripts/redact.sh` exists, `<note>` is piped through it first (best-effort -
  a failure of `redact.sh` falls back to the unredacted note rather than dropping the record).
- Idempotent on `(timestamp, kind, ref)`: a second `append` call with the same three fields
  prints the existing line and appends nothing, even if `<note>` differs. Idempotence is keyed
  to the second, not to note content, and `<ref>` itself is never masked by `redact.sh`.

## C8 - raw journal file (`hooks/raw-journal.sh`)

File: `<project-root>/.litopys/raw/<session_id>.md`, one file per Claude Code session (the
session id is sanitized to `[A-Za-z0-9._-]` before use as a filename). `.litopys/` carries its
own `.gitignore` (`*`) so no host project's own `.gitignore` needs an entry.

Frontmatter, written once on the first hook call of a session (`ensure_journal`):
```
---
litopys: raw
version: 1
session_id: <sid>
started: <ISO-8601 UTC timestamp>
cwd: <payload cwd, or project root>
branch: <git -C cwd symbolic-ref --short HEAD, or rev-parse --abbrev-ref HEAD, or "-">
---
```

Body blocks, appended in event order, each preceded by a blank line:
- `## user · <ts>` followed by the verbatim prompt text (`UserPromptSubmit`, reading
  `.user_input` then falling back to `.prompt`).
- `## assistant · <ts>` followed by the verbatim `last_assistant_message` (`Stop`). Only the
  *last* assistant message of a turn is captured - any intermediate assistant text before that
  Stop is not recorded. A `Stop` event carrying a non-empty `agent_id` (a subagent's Stop, not
  the main session's) is skipped entirely - a fork's turns never land in the parent's journal.
- `## closed · <ts> · <reason>` (`SessionEnd`) - appended only if the journal file already
  exists; a session that produced no prompt/assistant block gets no journal file and `end`
  creates nothing. This is the only block with no `timeout` in `hooks/hooks.json` - it must run
  inside `SessionEnd`'s own ~1.5s budget, so it does exactly one file append and nothing else
  (no `mkdir`, no git call, no scan).

Every failure path in both hooks (missing `jq`, empty/malformed/non-object stdin payload, no
writable `.litopys/`) is fail-open: the hook prints nothing and exits 0, so a journal that
cannot be written never breaks the session it would have recorded.

See also `memory/map/litopys-plugin.md` for the CLI/hooks/skill entry points these formats
belong to, and C9 (the SessionStart banner) which reads chronicle files and raw-journal counts
but writes neither format itself.
