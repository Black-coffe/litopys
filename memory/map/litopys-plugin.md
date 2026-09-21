# Scout report: litopys plugin

## Purpose
Phase 0-1 (spec `litopys-phase-0-1`, v0.1.0, merged `efedfce`): a model-free chronicle CLI,
four raw-journal hooks and one `/litopys:recall` skill/agent pair, shipped as a Claude Code
plugin (`.claude-plugin/plugin.json`) loaded with `--plugin-dir`.

## Entry points (CLI - `bin/litopys`)
- `append --kind <grill|brief|verdict|ship|handoff|note> --ref <path|sha> [--note "<text>"]`
  (C1-C3): appends one dated line to `<root>/docs/chronicle/YYYY-MM.md`, creating the header
  if missing. Idempotent on `(ts, kind, ref)` - a repeat prints the existing line, writes
  nothing. Pipes `--note` through the host's `scripts/redact.sh` when present (C3); multi-line
  notes collapse to one line (`tr '\n\r\t' ' '`).
- `bench` (C1, C4, C5): parses `<root>/docs/chronicle/golden-questions.md` (exactly five
  `## Q<n> · <question>` sections, each with `- answer:` and `- refs:`), runs each through
  `claude -p --plugin-dir <plugin_root> --model sonnet --output-format json
  "/litopys:recall <q>"` (override binary via `LITOPYS_CLAUDE`), and appends one JSON row per
  question to `<root>/.litopys/baseline.jsonl`. Never reads stdin (children get `</dev/null`).
  Requires `jq`; malformed questions/missing file exit 2, nothing written.
- `--version`/`help`: static (version `0.1.0`).
- `project_root()` (C1): `CLAUDE_PROJECT_DIR` (if a dir) -> `git rev-parse --show-toplevel` ->
  `$PWD`. Hooks use the same precedence with the payload's `cwd` inserted before the git step.

## Key types / contracts
- **C3 chronicle line**: `- <ISO ts> · <kind> · <ref> · <note>` in `docs/chronicle/YYYY-MM.md`.
  Full reference: `docs/wiki/chronicle-format.md`.
- **C4 golden-questions.md**: 5 `## Q<n> · <question>` sections with `answer:`/`refs:`
  (pipe/semicolon separated); malformed -> `bench` exits 2, one stderr line, nothing written.
- **C5 baseline.jsonl row** (one per question per run, append-only): `ts, project, q, question,
  hit, refs_expected, refs_matched, tokens_in, tokens_out, cost_usd, seconds, model, litopys`
  (+`error` on a failed call). `tokens_in`/`tokens_out` sum ALL of `usage`'s input fields
  (uncached + cache_creation + cache_read), falling back to summing `modelUsage` (camelCase)
  when `usage` is present but all-zero; `null` only when neither object exists
  (`bin/litopys` `BENCH_USAGE_JQ`, ~line 126). A call is scored failed on `claude` exiting
  non-zero OR `"is_error":true` in the JSON (an error report in `.result`, never an answer) -
  both still write a row.
- **C7/C8 raw journal** (`hooks/raw-journal.sh` -> `.litopys/raw/<session_id>.md`): YAML
  frontmatter (`litopys: raw`, `version: 1`, `session_id`, `started`, `cwd`, `branch`) then
  `## user · <ts>` / `## assistant · <ts>` / `## closed · <ts> · <reason>` blocks. Subagent
  Stop events (non-empty `agent_id`) are skipped. Every failure path is `exit 0`. Full
  reference: `docs/wiki/chronicle-format.md`.
- **C9 SessionStart banner**: exactly 5 `[litopys] ...` lines via
  `hookSpecificOutput.additionalContext` (version + "project chronicle", chronicle file count,
  newest chronicle date across all month files, unconsolidated raw-journal count, the recall
  hint). Degrades to one static line without `jq`.

## Hooks (`hooks/hooks.json`)
- `UserPromptSubmit` -> `raw-journal.sh prompt` (timeout 10) - opens/appends `## user`.
- `Stop` -> `raw-journal.sh stop` (timeout 10) - appends `## assistant` (skipped for subagent Stop).
- `SessionEnd` -> `raw-journal.sh end` (no timeout key; must fit SessionEnd's own ~1.5s budget) -
  appends `## closed` only into a journal that already exists.
- `SessionStart` -> `session-start.sh` (timeout 10) - prints the 5-line banner.
All four run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` so Windows never depends on PATH
exec of an extension-less file (same rationale as `bin/litopys`, C2).

## Recall skill/agent pair
- `skills/recall/SKILL.md` (`/litopys:recall <question>`, `context: fork`, `agent: recall`,
  `allowed-tools: Read, Grep, Glob, Bash(git log:*/tag:*/show:*)`) forks into `agents/recall.md`
  (`model: sonnet`, `tools: Read, Grep, Glob, Bash`).
- Search order (kept identical in both files): `docs/chronicle/` -> `docs/specs/*/brief.md` ->
  `docs/adr/` -> `docs/grill/` -> `CHANGELOG*` -> `git tag` -> `git log --oneline` (drill down
  with `git show`/`git log -S`), stopping as soon as it can answer confidently.
- Return shape (only this reaches the caller - the fork hides the search transcript):
  `**Answer:** <=10 lines` / `**Refs:** - <path or 7-char sha> - <why>` / `**Confidence:**
  high|medium|low`. No match -> `Not found in project history. Searched: <stages>.` with
  `**Refs:** (none)` and `**Confidence:** low`.

## Tests and fixtures
- `tests/append.test.sh` - `append`'s C1-C3 contract: idempotence, multi-line collapse,
  `redact.sh` masking (present/absent), argument errors (exit 2, nothing written), git-toplevel
  fallback, `--version`.
- `tests/bench.test.sh` - `bench`'s C1/C4/C5 contract against `tests/fixtures/claude-stub.sh`
  (a `claude` stand-in selected by keyword in the question, logging argv/cwd when
  `LITOPYS_STUB_LOG` is set) and `tests/fixtures/golden-questions.md` (5 fixture questions:
  alpha=hit+both refs, beta=hit+1 of 2 refs via the `modelUsage` fallback, gamma=miss,
  delta=stub exits 1, epsilon=hit with no usage block at all). Also covers `is_error:true`
  scoring as a miss (not a hit), `bench` never reading stdin (an open fifo must not block it),
  and malformed golden-questions exiting 2 with nothing written.
- `tests/hooks.test.sh` - `hooks.json` wiring (types, `CLAUDE_PLUGIN_ROOT` command form,
  timeouts), raw-journal frontmatter/blocks/subagent-skip/branch-fallback, the SessionEnd
  closing line finishing within a second, the SessionStart banner's exact 5-line shape, and
  fail-open behaviour (malformed/empty/non-object stdin, no `jq`, unwritable `.litopys/`).
- None of the three suites call a real model; `tests/fixtures/claude-stub.sh` stands in for
  `claude` in `bench.test.sh` only.

## Phase-0 baseline (in a host project)
`examples/vulyk/golden-questions.md` - five golden questions about VULYK itself, written
2026-09-21 before any distillation (sources: VULYK's own git log/CHANGELOG/ADRs/grills/specs).
The phase-0 baseline measured against them via `bin/litopys bench` run inside a VULYK checkout:
`hits 4/5 · refs 7/8 · 143s` (`CHANGELOG.md` `[0.1.0]`). This is an example fixture meant to be
copied into a host project's `docs/chronicle/golden-questions.md` - litopys's own repo has
neither a `docs/chronicle/` nor a golden-questions file of its own yet.

## Dependencies
- `append` shells to the host's `scripts/redact.sh` when present (optional, degrades to
  passthrough); this repo's own `scripts/redact.sh` (copied from VULYK) exists only so
  `tests/append.test.sh` can exercise the masking path - `.claude-plugin/plugin.json` does not
  name it, a host project supplies its own.
- `bench` requires `jq` on PATH and a `claude` binary (`LITOPYS_CLAUDE` override).
- `raw-journal.sh`/`session-start.sh` require `jq`; degrade to a no-op / one static banner line
  without it. No model call happens inside any hook; `agents/recall.md` runs on `sonnet`.

## Gotchas
- `bin/litopys` and both hook scripts each implement C1 root resolution independently (CLI:
  env -> git -> pwd; hooks: env -> payload `cwd` -> git -> pwd) - there is no shared sourced
  library, so a change to root resolution must be made in all three files.
- `bench`'s `BENCH_USAGE_JQ` deliberately sums cache-creation and cache-read tokens into
  `tokens_in` - reading only `usage.input_tokens` reads ~0 on every real call because Claude
  Code reports the uncached slice separately from the (much larger) cache fields.
- `raw-journal.sh`'s `end` mode is the only one with no `timeout` key in `hooks.json`
  (SessionEnd's own ~1.5s budget applies) and does exactly one `>>` append -
  `tests/hooks.test.sh` asserts this by grepping the `journal_end()` function body for exactly
  one `>>`.
- Known limits carried into phase 2 (`CHANGELOG.md` `[0.1.0]`): `--ref` is never redacted;
  idempotence keys on `(ts, kind, ref)` to the second, not on note content; a resumed session
  appends past its `## closed` marker; `claude plugin validate . --strict` is red in this repo
  (conflicts with the root VULYK `CLAUDE.md`) - the non-strict form is the build check actually
  used (`CLAUDE.md` `## Commands`).

last-verified: 2026-09-21 (v0.1.0, spec litopys-phase-0-1, merge efedfce)
