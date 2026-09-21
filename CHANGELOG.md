# Changelog

All notable changes to litopys. Format: Keep a Changelog; versions follow semver.

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
