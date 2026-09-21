---
story: litopys-phase-0-1-03
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 2
blocked_by: [litopys-phase-0-1-01]
---

# Golden questions for VULYK, written before any distillation

## Goal
After this story `examples/vulyk/golden-questions.md` (in this repo; copied to `examples/vulyk/golden-questions.md` by the owner at the baseline gate) holds five questions about VULYK's history, each with a known answer keyphrase and verified references, in the machine-readable shape `bench` (story 04) parses. They are the fixed yardstick every later phase is measured against, so they are written now, from primary sources, with no distilled material in existence.

## Requirements
> `docs/chronicle/golden-questions.md` для VULYK: 5 вопросов с известным ответом и ссылкой (среди них «что было в релизе до 0.1, как брейнштормили, что устарело»), записанных до любой дистилляции;

## Files
- examples/vulyk/golden-questions.md

## Non-goals
- Do not write more than five questions; do not write questions whose answer is in CLAUDE.md or memory/ alone - the point is history (git, CHANGELOG, specs, ADR, grills).
- Do not run `bench`, `recall`, or any model to pick the answers; verify each by reading the source file or `git show`.
- Do not write into E:/Projects/vulyk; read it (git log, CHANGELOG, docs/) only.
- Do not commit in the VULYK repo - the Queen commits there after the story returns.
- Do not edit anything else in E:/Projects/vulyk.

## Map slice
Contract C4 in plan.md (file shape). Sources to read, all in E:/Projects/vulyk: `git log --oneline --reverse | head -80`, `git tag`, `CHANGELOG.md`, `docs/adr/*.md` (ADR-001 and ADR-007 at least), `docs/specs/*/brief.md`, `docs/grill/*.md`.

## Acceptance criteria
- The finished file has been passed through `bash scripts/redact.sh` (stdin→stdout) and the redacted output is what is committed; the diff between the two is empty or explained in Implementation notes.
- [ ] File follows C4 exactly: header, one HTML comment naming date and sources, five `## Q<n> · ` sections each with `- answer:`, `- refs:`, `- source:`.
- [ ] Q1 is the mandated compound question, worded in Russian as the brief has it: «что было в релизе до 0.1, как брейнштормили, что устарело». Its `answer:` lists keyphrases that a correct answer must contain (e.g. the earliest tag or version string and the ADR or grill that was superseded); its `refs:` name the CHANGELOG section and at least one sha7 or ADR file.
- [ ] The other four cover different eras or kinds of fact: one about a version's headline change, one about an ADR decision and why, one about a grill or spec decision, one about something that was later removed or replaced. No two questions share a ref.
- [ ] Every `answer:` keyphrase is short and distinctive (a version, a slug, an ADR id, a script name) - a case-insensitive substring match on it must not fire on an unrelated answer.
- [ ] Every `refs:` entry exists on disk or in `git log` of E:/Projects/vulyk today; the worker checked each and says so in `- source:`.
- [ ] Implementation notes record the exact git commands used, so the Queen can audit.

## Verification
`grep -c '^## Q[1-5] · ' examples/vulyk/golden-questions.md | grep -qx 5 && grep -c '^- answer: ' examples/vulyk/golden-questions.md | grep -qx 5 && grep -c '^- refs: ' examples/vulyk/golden-questions.md | grep -qx 5`

## Implementation notes
- Wrote `examples/vulyk/golden-questions.md` (this repo) per C4 shape; all facts sourced from `E:/Projects/vulyk` only, no writes made there.
- Git commands run in `E:/Projects/vulyk` to verify each fact: `git log --oneline --reverse | head -80`; `git tag | sort -V | head -5`; `sed -n '1,60p' CHANGELOG.md`; `grep -n "^## \[0\." CHANGELOG.md`; `sed -n '1087,1142p' CHANGELOG.md` ([0.2.0]/[0.1.0] sections); `git show --stat 21760d6` (confirms v0.1.0 is the repo's root commit); `sed -n '783,830p' CHANGELOG.md` ([0.7.0]); `git show --stat 86ee548`; `ls scripts/trace-check.sh`; `sed -n '1,40p' docs/adr/007-model-ladder.md` (read but not used, see below); `sed -n '1,30p' docs/adr/001-cycle-state-contract.md` + `grep -n "^## Decision" -A8`; `sed -n '1,30p' docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md`; `git show --stat 7d243a9`; `ls docs/specs/autonomous-cycle/autonomous-cycle-05-council-agents.md`.
- Q1 is the mandated compound question. Its answer is that no release predates v0.1.0 (it is the repo's root commit, `git show 21760d6 --stat`); the "brainstorm" is the grill `docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md`, which proposed a subtraction release; what became obsolete is that very plan - CHANGELOG's `[0.2.0]` section opens "Additive: nothing was removed", i.e. the grill's own subtraction verdict was overturned before shipping.
- Considered ADR-007 (model ladder) for the ADR question but used ADR-001 instead to avoid crowding the answer set toward one spec (`lean-cascade` vs `autonomous-cycle`) and because ADR-001's context/decision (Workflow runtime has no filesystem/clock) is more self-contained to verify from the ADR file alone.
- Ran `bash scripts/redact.sh < examples/vulyk/golden-questions.md` and diffed against the source file: empty diff, no redaction needed.
- Checked refs for cross-question overlap; adjusted Q2 to drop `CHANGELOG.md` (already used as a ref base in Q1) in favour of `scripts/trace-check.sh`, so no two questions share a ref.

## Findings
