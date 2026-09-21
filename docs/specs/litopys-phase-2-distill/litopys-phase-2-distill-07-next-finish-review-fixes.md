---
story: litopys-phase-2-distill-07
spec: litopys-phase-2-distill
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 5
blocked_by: [litopys-phase-2-distill-06]
---

# Review round 1 fixes: `distill next` never touches a live session, `finish` commits only what it wrote

## Goal
Four findings from `council/round-1/review.md` (critical 1, majors 2-4) are closed in `bin/litopys`. `distill next` applies the skip rule only to *eligible* journals, so a running `/litopys:distill` session's own journal is left in place and the self-referential fragment never exists; a journal with no `## user` block is skipped, not distilled; a journal whose record already exists (a resume after distillation) is parked in `skipped/` instead of occupying a cap slot forever; the ordering list no longer passes paths through `printf %b`, so a Windows backslash root works. `distill record` appends every path it writes to a run manifest `.litopys/distill.paths`, and `distill finish` stages and commits exactly those paths - never the whole `docs/chronicle/` directory.

## Requirements
> redact; коммит мимо рабочих веток; lock + cap N очереди
> the distiller writes the record and the chronicle line into the working tree and commits *only those paths* on the current branch (`git commit -- docs/chronicle/`), never touching staged or unstaged work outside `docs/chronicle/`
> journals whose first `## user` line starts with `/litopys:recall` or `/litopys:distill` are skipped and moved to `.litopys/raw/skipped/`, never distilled
> After `## closed`, a further prompt re-opens the same journal file and appends past the close marker ... the phase-2 consolidator will need a rule for journals with a close marker in the middle.
> Review round 1 critical 1: `distill next` must never move or select a journal whose session may still be running - the skip rule applies only to journals that already pass the eligibility rule; a journal without any `## user` block is skipped, not distilled (C12 step 2 amended).
> Review round 1 major 2: the ordering list must carry file paths without passing them through printf escape interpretation (C12, Windows backslash roots).
> Review round 1 major 3: the distill commit must contain only the record files and month files this run wrote - `distill record` appends each path it writes to `.litopys/distill.paths`; `distill finish` stages and commits exactly those paths and `<n>` counts the distinct record paths (C11/C12 amended; replaces the `docs/chronicle` directory pathspec).
> Review round 1 major 4: a journal whose record already exists is parked by `next` into `.litopys/raw/skipped/<sid>.resumed.md` and counted as skipped (C12/C13 amended); the resumed part of an already-distilled session is not chronicled in phase 2.

## Files
- bin/litopys
- tests/distill.test.sh

## Non-goals
- Do not touch the lock protocol, the cap, the 60-minute mtime rule, the 30-minute stale rule, or the stderr line's three-field shape (`skipped <s> · pending <p> · selected <k>` stays one line; parked journals count in `s`).
- Do not change `record`'s body validation, record shape, redaction, or `--force` semantics; the only `record` change is the manifest append.
- No resume merge: a resumed journal is parked, not re-distilled and not merged into its record. No `resumed/` directory - `skipped/` with the `.resumed` suffix (a second resume of the same sid must not overwrite the first: add a numeric suffix).
- Do not change the refusal list, the commit message format, or `finish`'s exit-0 rule; do not read `distill.jsonl` in `finish`.
- Minors 6-10, 12, 15 of the review are not this story; do not fix them here, even if adjacent.
- Do not touch hooks, `agents/`, `skills/`, `bench`, `append`, fixtures, `plugin.json`, `CHANGELOG.md`.

## Map slice
`memory/map/litopys-plugin.md` - Entry points (CLI), Gotchas; story 04 `## Implementation notes` (`journal_scan()`, `\x1f` delimiter, `sort -n` ordering) and story 05 `## Implementation notes` (`distill_finish`, `git_block_reason`, `<n>` counting); plan.md C11, C12, C13 and `## Plan deltas`; `council/round-1/review.md` findings 1-4 (the reproduction steps are there).

## Acceptance criteria
- [ ] Order of operations in `next`: eligibility (last `## ` header is `## closed`, or mtime older than 60 min) is decided for every top-level journal first; the skip rule (first `## user` line starts with `/litopys:recall` or `/litopys:distill`, **or** no `## user` block at all) moves only eligible journals to `skipped/`; an ineligible journal is never moved, whatever its first line.
- [ ] Test: an open journal (last header `## assistant`, fresh mtime) whose first user line is `/litopys:distill` stays at the top level after `next`, is not printed, and counts in `pending`; the same file aged 61 minutes is moved to `skipped/` and counts in `skipped`. The former N3 assertion ("user-less journal is normal") is replaced: a closed journal with no `## user` block goes to `skipped/`.
- [ ] Test: an eligible journal whose `docs/chronicle/sessions/<date>-<sid8>.md` already exists is moved to `skipped/<sid>.resumed.md`, counted in `skipped`, not printed; a following `next` no longer sees it; a second such journal for the same sid does not overwrite the first parked file.
- [ ] The ordering list is built and consumed without `printf %b` (or any `%b`/`echo -e` on a path). Test: with `CLAUDE_PROJECT_DIR` set to a backslash root (`cygpath -w "$P"` when `cygpath` exists, else a subdirectory literally named `\Users\temp` created under the temp project), `next` prints the eligible paths, stderr is exactly one line, exit 0.
- [ ] `distill record` appends the record path and the month-file path (repo-relative, one per line) to `<root>/.litopys/distill.paths` after a successful write; a failed `record` (exit 2) appends nothing.
- [ ] `distill finish` reads `.litopys/distill.paths` (deduplicated), runs `git add -- <paths>` and `git commit -m "chore(chronicle): distill <n> session(s) [litopys]" -- <paths>` with `<n>` = distinct `docs/chronicle/sessions/*.md` paths in the manifest; missing or empty manifest -> `uncommitted: nothing to commit`. The manifest is removed on `committed` and on `nothing to commit`, kept on every refusal so a later `finish` can commit the same paths.
- [ ] Test: an unrelated untracked file `docs/chronicle/golden-questions.md` and an unstaged edit to a tracked `docs/chronicle/2020-01.md` exist before `finish`; after `committed <sha7>`, `git show --stat HEAD` lists only the record and the month file this run wrote, the untracked file is still untracked, the edit still unstaged. Existing F1-F11 assertions still hold (`put_record` may need to go through `distill record` so the manifest exists).
- [ ] `<n>` is 2 for a two-record run and 1 for a `--force` re-distillation of one record (a second chronicle line no longer inflates it).
- [ ] Every file LF; `bash -n bin/litopys` clean; no model call.

## Verification
`bash tests/distill.test.sh`

## Implementation notes


- `bin/litopys` - `journal_scan` now emits a 4th `\x1f` field, `session_id` (the resume check in
  `next` needs it); callers read `started firstuser lastheader sid`.
- `distill_next` is one loop instead of three: eligibility first, then the skip rule (bench **or**
  empty `firstuser`), then the resume park, then the sort key. `remain` (= `pending`) is every
  journal still at the top level, unchanged in meaning.
- Ordering list built with real `$'\t'`/`$'\n'` and consumed with `printf '%s'`; the `eligible`
  column is gone because only candidates now enter the list.
- Resume park name: `skipped/<sidsafe>.resumed.md`, then `.resumed.2.md`, `.3`... `sidsafe` is the
  same `tr -c 'A-Za-z0-9._-'` sanitiser `record` uses for `done/`.
- `distill record` appends `<rel>` and `docs/chronicle/<YYYY-MM>.md` to `.litopys/distill.paths`
  after `cmd_append`; the month is cut from the same `$now` `cmd_append` uses.
- `distill finish` reads that manifest (deduped, existing paths only), `git add`/`git commit` with
  it as the pathspec, `<n>` = distinct `docs/chronicle/sessions/*.md` entries. Manifest deleted on
  `committed` and on `nothing to commit`, kept on every refusal (asserted in `refuses()`).
- Decision: the manifest filters out paths missing from disk rather than failing - `git add` on a
  vanished pathspec would otherwise turn a whole run into `uncommitted: pathspec ... did not match`.
- Surprising: the backslash-root case was verifiable for real here - `cygpath` exists, so N3c runs
  against `E:\Projects\...`. Reverting only line 795 back to `printf '%b'` turns 3 of its 4
  assertions red with git-bash's `printf: missing unicode digit for \U`, so the test has teeth.
- Usage text for `distill next`/`distill finish` updated to match the new behaviour (same file).

## Findings
