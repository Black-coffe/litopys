# Changelog

All notable changes to litopys. Format: Keep a Changelog; versions follow semver.

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
