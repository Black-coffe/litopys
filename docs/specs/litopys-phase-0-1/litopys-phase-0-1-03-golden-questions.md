---
story: litopys-phase-0-1-03
spec: litopys-phase-0-1
status: todo
returned:
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
- [ ] File follows C4 exactly: header, one HTML comment naming date and sources, five `## Q<n> · ` sections each with `- answer:`, `- refs:`, `- source:`.
- [ ] Q1 is the mandated compound question, worded in Russian as the brief has it: «что было в релизе до 0.1, как брейнштормили, что устарело». Its `answer:` lists keyphrases that a correct answer must contain (e.g. the earliest tag or version string and the ADR or grill that was superseded); its `refs:` name the CHANGELOG section and at least one sha7 or ADR file.
- [ ] The other four cover different eras or kinds of fact: one about a version's headline change, one about an ADR decision and why, one about a grill or spec decision, one about something that was later removed or replaced. No two questions share a ref.
- [ ] Every `answer:` keyphrase is short and distinctive (a version, a slug, an ADR id, a script name) - a case-insensitive substring match on it must not fire on an unrelated answer.
- [ ] Every `refs:` entry exists on disk or in `git log` of E:/Projects/vulyk today; the worker checked each and says so in `- source:`.
- [ ] Implementation notes record the exact git commands used, so the Queen can audit.

## Verification
`grep -c '^## Q[1-5] · ' examples/vulyk/golden-questions.md | grep -qx 5 && grep -c '^- answer: ' examples/vulyk/golden-questions.md | grep -qx 5 && grep -c '^- refs: ' examples/vulyk/golden-questions.md | grep -qx 5`

## Implementation notes

## Findings
