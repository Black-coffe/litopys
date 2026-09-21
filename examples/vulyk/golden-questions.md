# Golden questions - VULYK

<!-- written 2026-09-21, before any distillation; sources: git log, CHANGELOG.md, docs/adr, docs/grill, docs/specs (all in E:/Projects/vulyk) -->

## Q1 · Что было в релизе до 0.1, как брейнштормили, что устарело?
- answer: v0.1.0 | docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md | additive
- refs: CHANGELOG.md#[0.2.0]; 21760d6; docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md
- source: `git tag | sort -V | head -1` and `git show 21760d6 --stat` show v0.1.0 is the repo's root commit (no earlier release exists); the grill's brainstorm proposed a subtraction release (cut a third of agents, a quarter of commands, half the hooks), but CHANGELOG.md's `[0.2.0]` section opens "**Additive: nothing was removed**" - the grill's own plan was the thing superseded before it shipped.

## Q2 · What did v0.7.0 add to the planning stage, and what enforces it?
- answer: trace-check.sh | brief.md
- refs: 86ee548; scripts/trace-check.sh
- source: CHANGELOG.md's `[0.7.0]` section ("Traceability spine") and `git show 86ee548 --stat` confirm `scripts/trace-check.sh` and `docs/specs/<slug>/brief.md` (verbatim request, piped through `redact.sh`) were both added in this release; `scripts/trace-check.sh` exists on disk today.

## Q3 · What does ADR-001 decide about where the cycle's state lives, and why?
- answer: ADR-001 | Workflow runtime
- refs: docs/adr/001-cycle-state-contract.md
- source: `docs/adr/001-cycle-state-contract.md` ("one truth on disk, two thin drivers") - decided because the Workflow runtime "has no filesystem, no shell, no Node API and no clock", so it cannot hold a round counter or write a ledger; `cycle.sh` on disk is the one truth both drivers read.

## Q4 · What did the adversarial grill on the autonomous-cycle council brief conclude about stage 05?
- answer: stage 05 | adversarial
- refs: docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md
- source: `docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md` section 1.1 - it argues the brief's blind council does not replace the human stage 05 review, it triples `drone-acceptance` instead, and the honest framing is "we remove the human gate and compensate with a stronger up-front grill".

## Q5 · Which agent was retired in favour of drone-coverage judging by ask?
- answer: drone-acceptance | drone-coverage
- refs: 7d243a9; docs/specs/autonomous-cycle/autonomous-cycle-05-council-agents.md
- source: `git show 7d243a9 --stat` shows `.claude/agents/drone-acceptance.md` deleted (82 lines removed) in the same commit that adds `council-haiku/sonnet/opus.md` and `cycle-clerk.md` and changes `drone-coverage.md` to judge by ask, per the story file `docs/specs/autonomous-cycle/autonomous-cycle-05-council-agents.md`.
