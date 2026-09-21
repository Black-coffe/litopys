---
domain: chronicle-format
tags: [litopys, chronicle, journal]
related: [memory/map/litopys-plugin.md, docs/specs/litopys-phase-2-distill/plan.md, docs/wiki/session-record.md]
last-verified: 2026-09-21
---

# Chronicle line format (C3) and raw-journal file format (C8)

Two on-disk formats `bin/litopys` and `hooks/raw-journal.sh` write in a host project. Both are
model-free and append-only. Source: `bin/litopys` `cmd_append()` and `hooks/raw-journal.sh`
(spec `litopys-phase-0-1`, v0.1.0; amended by `litopys-phase-2-distill`, v0.2.0). The C11 session
record, the C12 resume queue and `distill.jsonl` are a separate format - see
`docs/wiki/session-record.md` for the C11 record shape and plan.md C11-C14 for the full contract.

## C3 - chronicle line (`bin/litopys append`)

File: `<project-root>/docs/chronicle/YYYY-MM.md`, one file per calendar month (UTC), created
with a `# Chronicle YYYY-MM\n\n` header on first write.

Line shape:
```
- <ISO-8601 UTC timestamp> · <kind> · <ref> · <note>
```
- `<kind>` is one of `grill brief verdict ship handoff note session` - any other value is
  rejected (`append` exits 2, nothing written). `session` is written by `distill record`
  through this same code path, so the monthly file keeps one writer.
- `<ref>` is a path or a sha, required. It is normalised before use, the same way `<note>` is
  collapsed: `\n`/`\r`/`\t` -> space, then the sequence ` · ` -> ` - ` (so a ref can never forge
  a second field). The normalised ref is then piped through the C16 redactor (below) exactly
  like `<note>`. A ref that is empty after normalisation is a usage error (`append` exits 2,
  nothing written).
- `<note>` is optional free text: newlines/carriage-returns/tabs collapse to single spaces
  before it is written, so one record is always exactly one line, then it is piped through the
  same C16 redactor.
- Idempotent on `(timestamp, kind, ref)`, keyed on the *normalised* ref: a second `append` call
  with the same three fields prints the existing line and appends nothing, even if `<note>`
  differs. Idempotence is keyed to the second, not to note content.

**C16 - redaction.** `bin/litopys` resolves one secret filter and uses it for both `<ref>` and
`<note>`, and for the whole C11 session record: the host project's own
`<project-root>/scripts/redact.sh` wins first (its patterns are the ones its owner maintains),
then the plugin's shipped `${CLAUDE_PLUGIN_ROOT}/scripts/redact.sh`, then the copy next to
`bin/litopys` itself (`<bin dir>/../scripts/redact.sh`, for when `CLAUDE_PLUGIN_ROOT` is unset);
none of the three present falls back to a plain passthrough (`cat`). Redaction is always
best-effort and never a gate: if the chosen filter fails, the record falls back to the
unredacted text rather than being dropped. The plugin's `scripts/redact.sh` is VULYK's own copy,
verbatim, with only the caller names in the header changed. Hooks (`hooks/raw-journal.sh`)
never redact - raw journals stay outside git untouched by any filter; redaction only happens on
the git-bound path (`append`, `distill record`).

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
- `## compact · <ts> · <manual|auto|->` (`PreCompact`) - appended only if the journal file
  already exists, the same guard as `## closed`, in its own `journal_compact()`. Distinct from
  `## closed`: it carries its own 10s `timeout` in `hooks/hooks.json` rather than running inside
  `SessionEnd`'s budget. The trigger value comes from the payload's `.compaction_trigger`,
  falling back to `.trigger`, else `-`.

**C13 - reading multiple `## closed`/`## compact` blocks.** One journal file is one session
record, whatever the number of `## closed` and `## compact` blocks it holds. A `## closed`
followed by more blocks is not a boundary - it is a process exit followed by a resume, and the
record spans all the blocks. `## compact` marks a point where the assistant's context was
summarised, not an exit; a resumed or compacted journal is never split or truncated.

Every failure path in both hooks (missing `jq`, empty/malformed/non-object stdin payload, no
writable `.litopys/`) is fail-open: the hook prints nothing and exits 0, so a journal that
cannot be written never breaks the session it would have recorded.

See also `memory/map/litopys-plugin.md` for the CLI/hooks/skill entry points these formats
belong to, and C9 (the SessionStart banner) which reads chronicle files and raw-journal counts
but writes neither format itself.
