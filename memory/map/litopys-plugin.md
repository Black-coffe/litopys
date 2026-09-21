# Scout report: litopys plugin

## Purpose
Phase 0-2 (spec `litopys-phase-2-distill`, v0.2.0, merging to main): a model-free chronicle CLI
plus a model-driven distillation loop. Six original kinds became seven; raw journals are turned
into git-tracked session records by a forked `distiller` agent, never by a hook. Shipped as a
Claude Code plugin (`.claude-plugin/plugin.json`) loaded with `--plugin-dir`.

## Entry points (CLI - `bin/litopys`)
- `append --kind <grill|brief|verdict|ship|handoff|note|session> --ref <path|sha> [--note
  "<text>"]` (C1-C3): appends one dated line to `<root>/docs/chronicle/YYYY-MM.md`. Idempotent
  on `(ts, kind, ref)` keyed on the normalised ref. `session` is written only by `distill
  record`, through this same function, so the monthly file keeps one writer.
- `bench` / `bench --delta` (C1, C4, C5, C15): `bench` runs the five `golden-questions.md`
  questions through `/litopys:recall` and appends rows to `.litopys/baseline.jsonl`; `--delta`
  sums the first five rows against the last five (hits, refs, seconds, tokens, cost - no model
  call) and requires >=10 rows, else exits 2.
- `distill record --journal <raw.md> --body <body.md|-> [--topics][--links][--source]
  [--model][--force]` (C11, C13, C16): validates the journal's frontmatter + C13 last-block scan
  and the body's four-section shape, writes `docs/chronicle/sessions/<date>-<sid8>.md`, appends
  one `session` chronicle line via `cmd_append`, appends the written paths to
  `.litopys/distill.paths`, moves the journal to `.litopys/raw/done/<sidsafe>.md`, appends one
  row to `.litopys/distill.jsonl`. Refuses (exit 2, nothing written) if the record already
  exists without `--force`, or the journal/body is malformed.
- `distill next [--max N]` (C12): takes the `mkdir .litopys/distill.lock` mutex (reclaimed after
  30 min), scans `.litopys/raw/*.md`, applies eligibility first (last block `## closed`, or
  mtime >60 min - "session may still be running" journals are never touched), then the skip rule
  (empty or `/litopys:recall`/`/litopys:distill` first user line -> `raw/skipped/`), then parks a
  resumed-after-distill journal (same session_id already has a record) as
  `raw/skipped/<sidsafe>.resumed[.N].md`, then prints up to N=3 (default) survivors oldest-first
  by `started` (mtime fallback) on stdout, and `skipped <s> · pending <p> · selected <k>` on
  stderr. Releases the lock itself only when nothing was selected (`k=0`); exit 3 + `locked` on
  stderr if another run holds it.
- `distill finish` (C12, C14): commits only the deduplicated, still-existing paths in
  `.litopys/distill.paths` on the current branch (`git add -- <paths>` then pathspec-limited
  `git commit`, no `-a`/`-A`/`--no-verify`), releases the lock unconditionally, deletes the
  manifest once committed or once empty. Prints `committed <sha7>` or `uncommitted: <reason>`
  (not a git repo, detached HEAD, merge/rebase/cherry-pick/revert in progress, or `nothing to
  commit`); always exits 0.
- `--version`/`help`: static (version `0.2.0`, `bin/litopys` line 18).
- `project_root()` (C1): `CLAUDE_PROJECT_DIR` (if a dir) -> `git rev-parse --show-toplevel` ->
  `$PWD`. Hooks use the same precedence with the payload's `cwd` inserted before the git step.
- `redactor()` (C16): host `<root>/scripts/redact.sh` -> `${CLAUDE_PLUGIN_ROOT}/scripts/
  redact.sh` -> the copy next to `bin/litopys` -> literal `cat`. Used by `append` (`--ref`,
  `--note`) and by `distill record` (the whole assembled record).

## Key types / contracts
- **C3 chronicle line / C16 redaction**: full reference `docs/wiki/chronicle-format.md`.
- **C11 session record** (`docs/chronicle/sessions/<date>-<sid8>.md`): full reference
  `docs/wiki/session-record.md`.
- **C4/C5/C15 bench**: golden-questions parsing, `BENCH_USAGE_JQ` (sums cache-creation +
  cache-read into `tokens_in`, falls back to `modelUsage`), `baseline.jsonl` row shape, and the
  `--delta` five-vs-five sum are unchanged from v0.1.0 aside from `--delta` itself (new in this
  phase) - see `bin/litopys` lines 170-260 for the exact fields.
- **C12 distill queue**: eligibility-before-skip ordering, the 30-min stale lock, the
  resumed-after-distill park rule, and N=3 default cap - see `bin/litopys` `distill_next()`
  (~line 669) and `docs/specs/litopys-phase-2-distill/plan.md` C11-C16 for the full contract
  text and rationale.
- **C7/C8 raw journal** (`hooks/raw-journal.sh` -> `.litopys/raw/<session_id>.md`): now four
  block kinds - `## user`, `## assistant`, `## closed`, and (new) `## compact · <ts> ·
  <manual|auto|->` on `PreCompact`. Full reference `docs/wiki/chronicle-format.md` (C13 covers
  reading files with multiple `## closed`/`## compact` blocks - one file is always one record).
- **C9 SessionStart banner**: still exactly 5 `[litopys] ...` lines; line 4 is now the distill
  queue, not a static hint - `[litopys] distill: <n> pending · run /litopys:distill` (n>=1) or
  `[litopys] distill: nothing pending` (n=0), where n = top-level `.litopys/raw/*.md` count only
  (`done/`, `skipped/` excluded, `hooks/session-start.sh` `count_md()`).

## Hooks (`hooks/hooks.json`)
- `UserPromptSubmit` -> `raw-journal.sh prompt` (timeout 10) - opens/appends `## user`.
- `Stop` -> `raw-journal.sh stop` (timeout 10) - appends `## assistant` (skipped for subagent Stop).
- `SessionEnd` -> `raw-journal.sh end` (no timeout key; must fit SessionEnd's own ~1.5s budget) -
  appends `## closed` only into a journal that already exists; exactly one `>>` in `journal_end()`.
- `SessionStart` -> `session-start.sh` (timeout 10) - prints the 5-line banner.
- `PreCompact` -> `raw-journal.sh compact` (timeout 10) - appends `## compact · <ts> · <trigger>`
  only into a journal that already exists; trigger reads `.compaction_trigger // .trigger // "-"`.
All five run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` so Windows never depends on PATH exec
of an extension-less file (same rationale as `bin/litopys`, C2).

## Distill skill/agent pair
- `skills/distill/SKILL.md` (`/litopys:distill [N]`, `context: fork`, `agent: distiller`,
  `allowed-tools: Read, Write, Grep, Glob, Bash`) forks into `agents/distiller.md` (`model:
  sonnet`). `$ARGUMENTS`, if non-empty, becomes `distill next --max $ARGUMENTS`.
- Procedure (C14): `distill next` (claim queue) -> per journal: Read it, Write a four-section
  body (`# title` / `## Decisions` / `## Problems` / `## Brainstorm` / `## Links`) to
  `.litopys/distill-<sid8>.body.md`, `distill record` it, `rm` the body -> `distill finish`.
  The agent never runs git, never writes a record/chronicle-line/commit itself, never moves a
  journal or touches the lock - the CLI owns all of that.
- Return shape: `**Distilled:** <n>` (one `- path - title` line per record) / `**Skipped:** <s>`
  / `**Commit:** <sha7>|uncommitted: <reason>|locked|nothing pending` / `**Pending:** <p>`.

## Recall skill/agent pair
- `skills/recall/SKILL.md` (`/litopys:recall <question>`, `context: fork`, `agent: recall`,
  `allowed-tools: Read, Grep, Glob, Bash(git log:*/tag:*/show:*)`) forks into `agents/recall.md`
  (`model: sonnet`, `tools: Read, Grep, Glob, Bash`).
- Search order (kept identical in both files, `docs/chronicle/sessions/` is new stage 1 this
  phase): `docs/chronicle/sessions/` (grep frontmatter `topics:`/`links:` first) ->
  `docs/chronicle/` -> `docs/specs/*/brief.md` -> `docs/adr/` -> `docs/grill/` -> `CHANGELOG*` ->
  `git tag` -> `git log --oneline` (drill down with `git show`/`git log -S`), stopping as soon as
  it can answer confidently.
- Return shape (only this reaches the caller): `**Answer:** <=10 lines` / `**Refs:** - <path or
  7-char sha> - <why>` / `**Confidence:** high|medium|low`. No match -> `Not found in project
  history. Searched: <stages>.` with `**Refs:** (none)` and `**Confidence:** low`.

## Tests and fixtures
- `tests/append.test.sh` - C1-C3 append contract (idempotence, redaction, argument errors, git
  fallback, `--version`).
- `tests/bench.test.sh` - C1/C4/C5 bench contract against `tests/fixtures/claude-stub.sh` and
  `tests/fixtures/golden-questions.md`.
- `tests/hooks.test.sh` - `hooks.json` wiring for all five events, raw-journal frontmatter/
  blocks/subagent-skip/branch-fallback, `## compact` block, the SessionEnd one-`>>` assertion,
  the SessionStart 5-line banner (including the distill pending line), fail-open behaviour.
- `tests/distill.test.sh` - C11/C13/C14/C16 `distill record` contract: record shape, redaction,
  `--force`, journal-move-to-done, run-manifest append, C13 multi-`## closed`/`## compact`
  reading, malformed journal/body rejection (exit 2, nothing written).
- None of the four suites call a real model; `tests/fixtures/claude-stub.sh` stands in for
  `claude` in `bench.test.sh` only.

## Dependencies
- `append`/`distill record` shell to the C16 redactor chain (optional, degrades to passthrough).
- `bench` requires `jq` on PATH and a `claude` binary (`LITOPYS_CLAUDE` override); `bench
  --delta` requires `jq`, no model call.
- `raw-journal.sh`/`session-start.sh` require `jq`; degrade to a no-op / one static banner line
  without it. No model call happens inside any hook; `agents/distiller.md` and `agents/recall.md`
  both run on `sonnet`.

## Gotchas
- `bin/litopys` and both hook scripts each implement C1 root resolution independently - no
  shared sourced library, so a change to root resolution must be made in all three files.
- `distill next` runs eligibility *before* the skip rule: a journal whose session may still be
  running (last block not `## closed` and mtime <60 min) is never parked or selected regardless
  of its first line - fixed in wave 5 after gate A moved a still-running distill session's own
  journal into `skipped/` mid-run (review round 1 critical 1).
- `distill finish` commits exactly the manifest paths (`.litopys/distill.paths`), never a
  `docs/chronicle` directory sweep - gate A's first run had swept an untracked host file under
  `docs/chronicle/` into the distill commit (review round 1 major 3) before this fix.
- `raw-journal.sh`'s `end` mode is the only one with no `timeout` key in `hooks.json`
  (SessionEnd's own ~1.5s budget applies) and does exactly one `>>` append.
- `bench`'s `BENCH_USAGE_JQ` deliberately sums cache-creation and cache-read tokens into
  `tokens_in` - reading only `usage.input_tokens` reads ~0 on every real call.
- Known limits carried forward: `claude plugin validate . --strict` is red in this repo
  (conflicts with the root VULYK `CLAUDE.md`) - the non-strict form is the build check actually
  used (`CLAUDE.md` `## Commands`); `tokens`/`tokens_est` in the record and `distill.jsonl` are
  byte-based estimates (`(journal_bytes + body_bytes) / 4`), not real model usage - a forked
  agent cannot read its own token count.

last-verified: 2026-09-21 (v0.2.0, spec litopys-phase-2-distill, merging to main)
