# Hive memory index

<!-- Pointer index: <= 60 lines, always loaded. Pointers are hints - verify against code before acting.
     Maintained by drone-docs (pointers) and librarian (hygiene). Humans welcome too. -->

## Codebase map
<!-- one line per mapped module, added by /vulyk-bootstrap and /vulyk-map -->
- `scripts/` (every gate/helper script, entry points, exit codes, callers): memory/map/scripts.md
- the cycle state contract as `cycle.sh` implements it (files, verbs, verdict rule, staleness,
  seat/court contracts, both drivers): memory/map/cycle.md
- every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (model, tools, report
  contract, what each command runs/never does): memory/map/agents-and-commands.md

## Unmapped territory
- `docs/` narrative pages (architecture.md, pipeline.md, cycle.md, token-economy.md,
  model-cascade.md, command-reference.md, getting-started.md) and `docs/adr/` beyond ADR-001
- `templates/`, `bootstrap/interview.md`, `.claude/hooks/`, `install.sh`, `scripts/vulyk-update.sh`'s
  own upgrade mechanics, `tests/` harness internals beyond what council.test.sh/cycle.test.sh
  cover, `.github/workflows/ci.yml` beyond the two test jobs

## Wiki domains
<!-- load-bearing domain notes in docs/wiki/ -->
- (none yet)

## Verification
<!-- the real ## Commands rows from CLAUDE.md - VULYK's own repo, no compiler, no test runner -->
- Shell syntax, all scripts: `git ls-files '*.sh' | xargs -n1 bash -n`
- Python syntax, hooks: `python -m py_compile .claude/hooks/*.py`
- JSON validity: `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
- Hook self-diagnosis: `bash .claude/hooks/handoff.sh status`
- Scope gate, per story: `bash scripts/scope-check.sh <story-file>`
- Story gate, per spec: `bash scripts/wave-check.sh docs/specs/<slug>`
- Ship gate, per spec: `bash scripts/ship-check.sh docs/specs/<slug>`
- Cycle status, per spec: `bash scripts/cycle.sh status docs/specs/<slug> --json`
- Cycle state contract tests: `bash tests/cycle.test.sh`
- Council verdict contract tests: `bash tests/council.test.sh`
- Full suite / build: none exists - VULYK has no test runner and no build step

## Learnings
- Model ladder and no Haiku below generation 5 (v0.13.0, 2026-09-14): docs/adr/007-model-ladder.md
- Deliverable before tier, plan stops for approval (v0.13.0, 2026-09-14): docs/adr/008-approval-stop-and-study-work.md
- Next brief's draft (round-2 UNASKED, ten review minors, ship-gate staleness on release paperwork): docs/specs/fable-review-remainders/plan.md `## Next circle`, CHANGELOG 0.13.1; the Fable majors of v0-12-0-remainders are closed there
- Dispatch failure reasons from verb exit codes, seat reports by file (v0.13.1, proposed): docs/adr/009-dispatch-failure-reasons-and-report-by-file.md

- Anomaly telemetry, opt-in (v0.14.0, 2026-09-15): docs/telemetry.md — `scripts/telemetry.sh`
  (enum/agents/consent/record/scan/bundle/check/publish/inbox), the Stop+SessionEnd
  `anomaly-scan.sh` hook, the installer consent question, the `/vulyk-evolve` weekly
  distil-and-clear; never sends on its own, `publish` only prints a copy recipe
- Driver hardening (v0.15.0, 2026-09-15): docs/adr/011-driver-hardening.md — clerk retry on a
  garbled relay, `skills.json`+`memory/learnings/*.md` as cycle paperwork, `close-story`
  tolerates a self-marked `status: done`, taint is the story file not a bare `<slug>-NN`, five
  mutating verbs carry post-verb `status`
- Consolidated: memory/learnings/CONSOLIDATED.md (run /vulyk-gc to refresh)
- Human gates rework (2026-09-12): memory/learnings/2026-09-12-human-gates-rework.md — один стоп в начале, дальше агентный совет; «owner looks» как обязательную стадию не возвращать
- Autonomous cycle / council (v0.12.0, 2026-09-13): docs/specs/autonomous-cycle/ — mechanics in docs/adr/001-cycle-state-contract.md (ADR-001), per-spec state in docs/specs/<slug>/journal.md
- Golden questions authored in plugin repo, copied at baseline gate (litopys 0.1.0, proposed): docs/adr/001-golden-questions-authored-in-plugin-repo.md
- Bench via `claude -p` + stub, cache-inclusive tokens (litopys 0.1.0, proposed): docs/adr/002-bench-via-claude-p-cache-inclusive-tokens.md
- Separate hook scripts, not routed through `bin/litopys` (litopys 0.1.0, proposed): docs/adr/003-separate-hook-scripts.md
- `.litopys/` self-ignoring scratch directory (litopys 0.1.0, proposed): docs/adr/004-litopys-scratch-directory.md
- Redaction delegated to host's `scripts/redact.sh`, plugin fallback deferred to phase 2 (litopys 0.1.0, proposed): docs/adr/005-redaction-delegated-to-host.md
- Phase-2 input, raw journal vs `/export` losses: docs/specs/litopys-phase-0-1/recon/raw-vs-export.md
- Distillation is skill-driven, no model calls from hooks (litopys 0.2.0, proposed): docs/adr/006-distillation-is-skill-driven-no-hook-model-calls.md
- Session records commit pathspec-limited on the current branch via a run manifest (litopys 0.2.0, proposed): docs/adr/007-pathspec-limited-commit-on-current-branch.md
- Distill queue: mkdir lock, N=3 oldest-first cap, first-user-line skip rule, done/skipped layout (litopys 0.2.0, proposed): docs/adr/008-distill-queue-lock-cap-skip-layout.md
- One raw journal file = one session record regardless of mid-file closed/compact markers (litopys 0.2.0, proposed): docs/adr/009-one-journal-file-equals-one-session-record.md
