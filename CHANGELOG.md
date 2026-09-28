# Changelog

All notable changes to litopys. Format: Keep a Changelog; versions follow semver.

## [0.3.0] - 2026-09-29

Private by default (spec `litopys-privacy-guard`, ADR-010).

### Security
- **Everything litopys generates stays out of git.** A managed block in the project's `.gitignore` covers `.litopys/` and `docs/chronicle/*` (`golden-questions.md`, which the owner writes, stays trackable). Nothing outside the block is touched.
- **Checked and announced every session.** The SessionStart hook runs `bin/litopys privacy`. It re-ensures the block, verifies it with `git check-ignore`, and tells the owner (`systemMessage`) and the model (banner line 6, "never git add -f these paths").
- **Loud when it matters.** The line turns into `[litopys] PRIVACY:` when the block had to be added or repaired, when a later rule overrides it, or when git already tracks litopys files. For tracked files it prints the exact untrack command; the index is never touched.
- **Records are no longer committed.** `/litopys:distill` ends with `kept local`. `LITOPYS_TRACK_CHRONICLE=1` is the explicit opt-in that restores the 0.2.x pathspec-limited commit for team repos.
- **A failing secret filter no longer lets a record through.** `distill record` refuses (exit 2, journal stays queued) instead of writing the unfiltered text.
- **The raw journal fails closed.** It is not written when `.litopys/.gitignore` cannot be. Every `.litopys/` writer in `bin/litopys` now goes through one `ensure_scratch` helper; several used to rely on another writer having created the self-ignore first.
- **The guard checks real files, not only probe names.** A rule that un-ignores actual litopys files (`git ls-files --others`) is reported, and the printed untrack command covers exactly the counted paths, nested `sub/.litopys/` included.
- **A symlinked `.gitignore` is never written through**, so a checkout cannot redirect the write outside the project.
- **`kept local` says only what git confirms**: outside git, or when a rule overrides the block, the line says so.
- **Journal frontmatter can no longer shape a record path.** The date must look like a date and the id keeps `[A-Za-z0-9_-]` only.

### Fixed
- `distill next` ordered the queue with GNU-only `date -d` / `stat -c`, so on macOS/BSD every journal read as epoch 0. It now sorts on the ISO `started` string, with `date -r` as the mtime fallback.
- A stale `distill.lock` is reclaimed by rename and re-check, so two reclaimers can no longer delete each other's fresh lock.
- `distill.jsonl` rows escape tab, CR and LF (and drop other control characters), so one row stays one valid JSON line, on every bash from 3.2 (stock macOS) up.
- The banner's chronicle count no longer counts `golden-questions.md` as a month file.
- The tests no longer use GNU-only `touch -d`.

### Changed
- `/litopys:recall` searches the git-ignored chronicle with `git grep --no-index --no-exclude-standard`: Claude Code's `Grep` (ripgrep) skips ignored files.
- The SessionStart banner is six lines (was five).
- The descriptions in `plugin.json` and `marketplace.json`, the README, the distiller's return shape (`kept local: <reason>`, the `committed ` prefix) and `agents/recall.md`'s tool claim now match the code.
- Removed six stale `.gitkeep` files.

## [0.2.1] - 2026-09-21

### Fixed
- `bin/litopys help` (and the bare `bin/litopys`) no longer prints two bash syntax errors to stderr: the usage text carried backticks inside an unquoted heredoc (council round 2 UNASKED, haiku seat).

## [0.2.0] - 2026-09-21

Phase 2 of the project-memory plugin (spec `litopys-phase-2-distill`).

### Added
- `bin/litopys distill record` - turns one raw journal plus a distilled body into a git-tracked `docs/chronicle/sessions/YYYY-MM-DD-<sid8>.md` record, appends one `session` chronicle line, and moves the journal to `.litopys/raw/done/`; writes one C14 cost row to `.litopys/distill.jsonl`.
- `bin/litopys distill next` - takes the `distill.lock` mutex (stale after 30 minutes), moves bench/recall journals to `.litopys/raw/skipped/`, and prints up to `--max` (default 3) eligible closed journals oldest-first.
- `bin/litopys distill finish` - commits only `docs/chronicle/` on the current branch (never the host's other staged or unstaged work) and releases the lock; always exits 0.
- `/litopys:distill` skill forking a sonnet `distiller` agent that reads up to three closed journals and writes their bodies.
- `PreCompact` hook marking compactions in the raw journal; the SessionStart banner's line 4 now reports pending journals to distill.
- `bin/litopys bench --delta` (C15) - prints the last five rows of `.litopys/baseline.jsonl` against its first five (hits, refs, seconds, tokens, cost) with no model call; fewer than ten rows exits 2.
- `--note`, `--ref` and every distilled record now pass through the host's `scripts/redact.sh` or the plugin's own copy - redaction no longer depends on the host alone.
- `--ref` normalisation: multi-line refs collapse to one line and their ` · ` separators are neutralised so a ref can never forge a chronicle field.

### Fixed
- `bench`'s `BENCH_USAGE_JQ` comment now explains why `usage.input_tokens` alone read ~0 on every real round-1 row, and why the cache fields are summed instead.
- `tokens_in`/`tokens_out` no longer double-count a `usage` object that carries both a snake_case and a camelCase spelling of the same field - snake_case wins per field, camelCase is the fallback only when snake_case is absent.
- `bench` writes an `"error":"unparsable stdout"` row (scored as a miss, `tokens_in: null`) when `claude` exits 0 with stdout that is not JSON at all.

## [0.1.0] - 2026-09-21

Phase 0-1 of the project-memory plugin (spec `litopys-phase-0-1`, council GREEN round 3).

### Added
- `bin/litopys append` - a model-free, idempotent, dated chronicle line into the host project's `docs/chronicle/YYYY-MM.md`, piped through the host's `scripts/redact.sh` when present.
- `/litopys:recall` skill forking a sonnet `recall` agent over the host's chronicle, specs, ADRs, grills, changelog and git history; fixed return shape (Answer / Refs / Confidence).
- `bin/litopys bench` - runs the host's `docs/chronicle/golden-questions.md` through recall via `claude -p` and appends one row per question to `.litopys/baseline.jsonl` (hit, refs matched, cache-inclusive tokens, cost, seconds).
- `examples/vulyk/golden-questions.md` - five golden questions for VULYK written before any distillation; the phase-0 baseline measured against them: `hits 4/5 · refs 7/8 · 143s`.
- Four hooks (`UserPromptSubmit`, `Stop`, `SessionEnd`, `SessionStart`) writing a raw per-session journal under `.litopys/raw/<session_id>.md`, closing it in under a second, and injecting a five-line SessionStart banner. No model calls inside hooks.
- `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` - what the raw journal loses against `/export` on one real >=100k-token VULYK session.
- Tests: `tests/append.test.sh`, `tests/bench.test.sh` (stub `claude`), `tests/hooks.test.sh`.

### Known limits (next circle)
- Redaction relies on the host project's `scripts/redact.sh`; `--ref` is never filtered.
- `append` idempotence is keyed on (ts, kind, ref) to the second; a multi-line `--ref` is not normalised.
- A resumed session appends past its `## closed` marker; the phase-2 consolidator needs a rule for that.
- `claude plugin validate . --strict` is red in this repo because of the root VULYK `CLAUDE.md`; the non-strict form is the build check.
