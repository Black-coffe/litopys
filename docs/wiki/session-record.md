---
domain: session-record
tags: [litopys, chronicle, distill, session-record]
related: [docs/wiki/chronicle-format.md, memory/map/litopys-plugin.md, docs/specs/litopys-phase-2-distill/plan.md]
last-verified: 2026-09-21
---

# C11 session record (`bin/litopys distill record`)

The git-tracked, distilled counterpart to a raw journal (see `docs/wiki/chronicle-format.md`
C8/C13 for the raw journal it is built from). Written only by `distill_record()` in
`bin/litopys` (spec `litopys-phase-2-distill`, v0.2.0) - never by a hook, never directly by the
`distiller` agent.

## File

`<project-root>/docs/chronicle/sessions/<started-date>-<sid8>.md`, where `<started-date>` is the
journal frontmatter's `started` cut to its first 10 characters (or today's UTC date if `started`
is absent), and `<sid8>` is the first 8 characters of the journal's `session_id`. Writing over an
existing record path exits 2 ("record exists: `<rel>` (use `--force`)") unless `--force` is
given.

## Frontmatter + body shape

```
---
litopys: session
version: 1
date: <YYYY-MM-DD>              # from the journal's `started`, or today's UTC date
session_id: <sid>               # verbatim from the journal frontmatter
started: <ISO ts | ->
ended: <ISO ts | ->              # see "ended" below
branch: <git branch | ->
topics: [a, b]                  # --topics, comma-split, trimmed, [] if empty/omitted
links: [x, y]                   # --links, comma-split, trimmed, [] if empty/omitted
source: live|backfill           # --source, default live
tokens: <int>                    # (journal_bytes + body_bytes) / 4 - a byte estimate, not real usage
model: <name>                    # --model, default sonnet
---
# <title>

## Decisions
- ...

## Problems
- ...

## Brainstorm
- ...

## Links
- ...
```

- **`ended`** is the journal's *last* `## closed · <ts> · <reason>` block, but only when `##
  closed` is also the file's last header line - anything after it (a resume, a `## compact`)
  makes the session still open as far as the record is concerned, and `ended` stays `-` (C13).
- The body must start with exactly one `# <title>` line, then exactly the four sections
  `## Decisions`, `## Problems`, `## Brainstorm`, `## Links`, in that order, each present once -
  any other shape (missing section, wrong order, extra section, no title) is rejected before
  anything is written (exit 2, journal untouched).
- The whole assembled record (frontmatter + body) is piped through the C16 redactor chain before
  it touches disk (`docs/wiki/chronicle-format.md` C16); a redactor failure falls back to the
  unredacted text rather than dropping the record.

## Side effects of one `distill record` call

In order, once the journal and body both validate:
1. The record file is written (redacted).
2. One `session`-kind chronicle line is appended to the monthly file via `cmd_append` itself
   (`--ref <rel> --note <title>`) - the monthly file keeps one writer.
3. `<rel>` and the month's chronicle path are appended to `.litopys/distill.paths` (the run
   manifest `distill finish` later commits from).
4. The source journal is moved to `.litopys/raw/done/<sidsafe>.md` (gitignored, kept indefinitely,
   re-distillable with `--force`).
5. One row is appended to `.litopys/distill.jsonl`: `{ts, session_id, record, journal_bytes,
   body_bytes, tokens_est, model, source, litopys}`.

A rejected journal or body (exit 2) leaves all five side effects undone - the journal stays where
it was, still distillable.

## Consumers

`agents/recall.md` / `agents/recall` (skill `/litopys:recall`) search
`docs/chronicle/sessions/` first, grepping the `topics:`/`links:` frontmatter before the body -
see `memory/map/litopys-plugin.md` "Recall skill/agent pair".
