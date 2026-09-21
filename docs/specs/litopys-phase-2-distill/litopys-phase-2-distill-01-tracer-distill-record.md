---
story: litopys-phase-2-distill-01
spec: litopys-phase-2-distill
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: true
wave: 1
blocked_by: []
---

# Tracer: `bin/litopys distill record` - one journal, one record, one line, redacted

## Goal
`bash bin/litopys distill record --journal <raw.md> --body <body.md>` exists: it reads a phase-1 raw journal (frontmatter, `## user`/`## assistant`/`## closed`/`## compact` blocks), builds the C11 record `docs/chronicle/sessions/YYYY-MM-DD-<sid8>.md`, pipes the whole record through the resolved redactor (C16), appends one `session` line to the monthly chronicle through `cmd_append`, moves the journal to `.litopys/raw/done/`, appends one C14 row to `.litopys/distill.jsonl`, and prints the record path. Along the way `append` gains the `session` kind, a shared `redactor()` helper, and `--ref` normalisation + redaction (C3 amended). No queue, no lock, no git commit - those are stories 04 and 05.

## Requirements
> `agents/distiller` sonnet; запись сессии = плоский файл с frontmatter (date, topics, links, source: live|backfill)
> `docs/chronicle/sessions/YYYY-MM-DD-<sid8>.md`, one flat markdown file per session with YAML frontmatter `date, session_id, topics, links, source: live|backfill, tokens, model`, plus one C3 line appended to `docs/chronicle/YYYY-MM.md` via `bin/litopys append --kind session --ref <that file>` so the monthly chronicle stays the index
> Redaction is conditional on the *host* project owning scripts/redact.sh ... the plugin is built to be dropped into any repo and ships no fallback filter of its own (e.g. $CLAUDE_PLUGIN_ROOT/scripts/redact.sh); `--ref` is never filtered at all.
> `bin/litopys append --ref` containing a newline or the ` · ` separator is not normalised, so a multi-line ref writes a two-line record and defeats (ts, kind, ref) idempotence.
> After `## closed`, a further prompt re-opens the same journal file and appends past the close marker ... the phase-2 consolidator will need a rule for journals with a close marker in the middle.
> the plugin ships `scripts/redact.sh`, VULYK's file copied verbatim with the caller names in the header changed; `append` and the distiller use the host's `scripts/redact.sh` when present, else the plugin's; `--ref` is collapsed to one line and passed through the same redactor as `--note`; a distilled record is redacted before it is written
> всё, что идёт в git, проходит scripts/redact.sh

## Files
- bin/litopys
- scripts/redact.sh
- tests/distill.test.sh
- tests/append.test.sh
- tests/fixtures/raw-resume.md
- tests/fixtures/distill-body.md

## Non-goals
- No `distill next`, no lock, no `skipped/`, no eligibility rule, no `git commit` (stories 04, 05). `distill` with no verb or an unknown verb prints usage, exit 2.
- Do not touch hooks, `agents/`, `skills/`, `plugin.json`, or `VERSION` (0.2.0 lands in story 06; the `litopys` key in the jsonl row uses `$VERSION` whatever it is).
- Do not change `scripts/redact.sh` below its header comment - it stays byte-identical to VULYK's body, mask `[VULYK:REDACTED]` included.
- Do not add a fifth body section, a `blocks:` key, or any frontmatter key C11 does not list.
- Do not create `tests/lib.sh`; copy the four helpers as the other suites do (plan `## Assumptions`).
- Do not change `bench`.

## Map slice
`memory/map/litopys-plugin.md` - Entry points (CLI), Key types C3/C7/C8, Gotchas (three root resolutions); `docs/wiki/chronicle-format.md` whole; `recon/plugin.md` Q2 (`bin/litopys:87-100` redact/collapse, `:297-305` dispatcher) and Q4 (test pattern); `recon/host-and-journal.md` "Raw journal format" and "redact.sh".

## Acceptance criteria
- [ ] `tests/fixtures/raw-resume.md` is a C8 journal with `## closed` mid-file, a later `## user`/`## assistant` pair, a `## compact · <ts> · auto` block, a final `## closed`, and one `sk-` shaped string in an assistant block. `tests/fixtures/distill-body.md` is a C11 body with a title, the four sections, one `ghp_` shaped token in `## Problems`.
- [ ] In a temp project with no `scripts/redact.sh` and `CLAUDE_PLUGIN_ROOT` set to this repo, `distill record --journal ... --body ... --topics a,b --links docs/x.md,abc1234` writes `docs/chronicle/sessions/<date>-<sid8>.md` whose frontmatter has exactly the C11 keys in C11 order, `ended` = ts of the final `## closed`, `topics: [a, b]`, `links: [docs/x.md, abc1234]`, `source: live`, `model: sonnet`, integer `tokens`; the body's `ghp_` token reads `[VULYK:REDACTED]`; the `sk-` string never appears in the record.
- [ ] `docs/chronicle/<YYYY-MM>.md` gains exactly one line `- <ts> · session · docs/chronicle/sessions/<file> · <title>`; the journal is now at `.litopys/raw/done/<sid>.md` and gone from the top level; `.litopys/distill.jsonl` has one row with the C14 keys and `tokens_est = (journal_bytes + body_bytes) / 4`.
- [ ] A host `scripts/redact.sh` that prints `HOSTMASK` for every line wins over the plugin's copy (record and chronicle note both show it).
- [ ] Second run without `--force`: exit 2, stderr names the record, no new chronicle line; with `--force`: record rewritten, a second line appended.
- [ ] Body missing a section, sections out of order, `--source other`, `--body -` on an empty stdin, or a journal without `session_id` in its frontmatter: exit 2, nothing written, journal not moved.
- [ ] `append --kind session --ref x` is accepted; `append --kind note --ref $'a\nb · c' --note n` writes one line whose ref is `a b - c`; `--ref 'AKIAABCDEFGHIJKLMNOP'` is masked in the written line; `--note` masking works in a project without `scripts/redact.sh` when `CLAUDE_PLUGIN_ROOT` is set (the existing "absent" test in `tests/append.test.sh` becomes the "plugin fallback" test; a case with both host and plugin absent - `CLAUDE_PLUGIN_ROOT` unset, `bin/litopys` copied to a dir without `../scripts/` - still passes the note through unchanged).
- [ ] `scripts/redact.sh` header names `bin/litopys append` and `bin/litopys distill record` as callers and says the host copy wins; body unchanged (`diff <(tail -n +N scripts/redact.sh) <(tail -n +N E:/Projects/vulyk/scripts/redact.sh)` is empty for the first body line N - read-only comparison, nothing written to VULYK).
- [ ] Every file LF; no test calls a model.

## Verification
`bash tests/distill.test.sh && bash tests/append.test.sh`

## Tracer
Layers this slice must cut through: journal parser (frontmatter + block headers, C13 rule) -> record assembly (C11) -> redactor resolution (C16) -> chronicle append (C3 path, new kind) -> journal move (C12 layout, `done/` only) -> cost row (C14 jsonl) -> test with a stub-free fixture pair. If the parser or the record shape wants to differ from C11/C13, report it in the INTERFACES line rather than improvising - stories 03 and 04 build against these contracts in parallel.

## Implementation notes
- Files: `bin/litopys` (KINDS +`session`, usage block, `redactor()`/`redact_filter()` C16 helpers,
  C3 ref normalise+redact in `cmd_append`, new `cmd_distill`/`distill_record`/`csv_list`/`json_str`/`bytes`),
  `scripts/redact.sh` (header only, 20 lines so the body still starts at line 21 in both copies),
  `tests/distill.test.sh` (new), `tests/append.test.sh`, `tests/fixtures/raw-resume.md`, `tests/fixtures/distill-body.md`.
- `redactor()` takes an optional root argument (defaults to `project_root()`) so `cmd_append`/`distill_record`
  do not resolve the root twice; it prints the literal `cat` when none of the three paths exists and
  `redact_filter` turns that into a plain `cat` (C16's "none -> cat" without ever running `bash cat`).
- The record is written through a `.tmp.$$` file and `mv`, so a redactor that dies mid-stream cannot leave
  a half-record on disk; the fallback then writes the unredacted record, as C16's best-effort rule says.
- Body validation is strict equality on the section list (`Decisions Problems Brainstorm Links`), which also
  rejects a fifth section - matches the story's non-goal, and is the same check for "missing" and "out of order".
- Surprise: with C16 the *plugin's* copy is always reachable in this repo, so `tests/append.test.sh`'s old
  "no redact.sh -> passthrough" case can only be reproduced by copying `bin/litopys` out of the repo with
  `CLAUDE_PLUGIN_ROOT` unset - that is now its own case beside the plugin-fallback one.
- Surprise: a host `redact.sh` that masks every line also masks the chronicle `--ref` (C3 amended sends the
  ref through the same filter), so the HOSTMASK test asserts `· session · HOSTMASK · HOSTMASK`.
- `tokens_est` and the record's `tokens` are the same integer; the test derives the expectation from the
  row's own `journal_bytes`/`body_bytes` and independently checks those two against the fixtures' sizes.

## Findings
