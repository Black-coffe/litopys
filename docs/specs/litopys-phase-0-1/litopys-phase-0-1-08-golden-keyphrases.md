---
story: litopys-phase-0-1-08
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 6
blocked_by: [litopys-phase-0-1-03]
---

# Fix round 1 / Ask 4: golden-question keyphrases that cannot self-match, refs that a recall answer can contain

## Goal
After this story `examples/vulyk/golden-questions.md` still holds the same five VULYK questions with the same verified facts, but every `answer:` keyphrase is absent from its own question text, is not a string that nearly any VULYK answer contains, and is not identical to one of that question's `refs:`; and every `refs:` entry is a repo-relative path or sha7 that a C6 `**Refs:**` line can literally contain. Council round 1 (lead-review majors 2, 3, 11): Q3 «ADR-001», Q4 «stage 05»/«adversarial», Q5 «drone-coverage» appear verbatim in their own questions and Q2 «brief.md» is ubiquitous, so an answer that merely restates the question scores `hit:true` (baseline saturated at 5/5, leaving phases 1-3 nothing to exceed); Q1's ref `CHANGELOG.md#[0.2.0]` can never match; Q1 uses one string as both keyphrase and ref.

## Requirements
> `docs/chronicle/golden-questions.md` для VULYK: 5 вопросов с известным ответом и ссылкой (среди них «что было в релизе до 0.1, как брейнштормили, что устарело»), записанных до любой дистилляции;
> Базовая линия «append + recall по тому, что уже есть» меряется ПЕРВОЙ, в фазе 0; фазы 1-3 оправдываются только её превышением (A2, D15).

## Files
- examples/vulyk/golden-questions.md

## Non-goals
- Do not change which five facts are asked, the Q1 wording mandated by the brief, or the C4 file shape; only keyphrases, refs and `source:` lines move.
- Do not write into E:/Projects/vulyk or copy the file there - the Queen re-copies it to `E:/Projects/vulyk/docs/chronicle/golden-questions.md` before the baseline re-run.
- Do not touch `bin/litopys`, `tests/` or `tests/fixtures/golden-questions.md` (story 07 owns the bench side in this wave).
- Do not run `bench` or `recall` to choose keyphrases; verify each by reading the source file or `git show` in E:/Projects/vulyk, as story 03 did.

## Map slice
Contract C4 and C6 return shape in plan.md. Story 03 Implementation notes (the git commands used, and why Q1's answer is «no release predates v0.1.0 / grill 2026-07-27 proposed subtraction / `[0.2.0]` shipped additive»). Review round 1 `council/round-1/review.md` majors 2, 3, 11.

## Acceptance criteria
- [ ] For every Q<n>, no `answer:` keyphrase is a case-insensitive substring of that question's `## Q<n> ·` line, and no keyphrase equals any entry in the same question's `refs:`.
- [ ] No keyphrase is one of the strings that occur in nearly any VULYK answer (`brief.md`, `plan.md`, `CLAUDE.md`, `VULYK`, `council`, `story`, a bare year); each is a version, tag, slug, sha7, ADR title word, script or file name that names the *answer*, not the *topic*.
- [ ] Every `refs:` entry is a repo-relative path that exists in E:/Projects/vulyk today or a sha7 present in its `git log`; no `#anchor`, no `[section]` suffix (Q1's CHANGELOG ref becomes `CHANGELOG.md` plus a sha7 or the grill path, keeping «no two questions share a ref» from story 03).
- [ ] Still exactly five `## Q<n> ·` sections, each with `- answer:`, `- refs:`, `- source:`; the `source:` line names how the new keyphrases were verified.
- [ ] The finished file is passed through `bash scripts/redact.sh`; the diff is empty or explained in Implementation notes.
- [ ] Implementation notes list, per question, old keyphrases -> new keyphrases and the reason, so the Queen can audit before re-copying.

## Verification
`grep -c '^## Q[1-5] · ' examples/vulyk/golden-questions.md | grep -qx 5 && grep -c '^- answer: ' examples/vulyk/golden-questions.md | grep -qx 5 && grep -c '^- refs: ' examples/vulyk/golden-questions.md | grep -qx 5 && ! grep -E '^- refs: .*[#\[]' examples/vulyk/golden-questions.md`

## Implementation notes
- Edited `examples/vulyk/golden-questions.md` only; verified every new fact by `git show`/`git log -S` in `E:/Projects/vulyk` (no `bench`/`recall` run), per the Non-goals constraint.
- Q1: `v0.1.0 | docs/grill/...opus-5.md | additive` -> `v0.1.0 | subtraction | additive` (dropped the grill-path keyphrase, which was identical to its own ref, major 11; replaced with "subtraction", the brainstorm's proposed release shape, verified in the grill file and `git show 1a55780`'s commit message). Ref `CHANGELOG.md#[0.2.0]` -> `CHANGELOG.md; 1a55780` (anchor stripped per C4/major 3; `1a55780` located via `git log -S'## [0.2.0]' -- CHANGELOG.md` in E:/Projects/vulyk, confirmed by `git show --stat` and reading the shipped `[0.2.0]` section, which opens "Additive release: nothing removed").
- Q2: `trace-check.sh | brief.md` -> `trace-check.sh | Traceability spine` (major 2: `brief.md` is ubiquitous across nearly any VULYK answer; replaced with the CHANGELOG `[0.7.0]` section's own title, verified by reading that section).
- Q3: `ADR-001 | Workflow runtime` -> `one truth on disk | Workflow runtime` (major 2: `ADR-001` is verbatim in the question line; replaced with the ADR's own decision phrase "one truth on disk, two thin drivers", verified by reading `docs/adr/001-cycle-state-contract.md`).
- Q4: `stage 05 | adversarial` -> `auto-ACCEPTED | мини-гриль` (major 2: both old keyphrases are verbatim in the question line; replaced with two terms unique to the grill's recommendation - `auto-ACCEPTED` occurs exactly once repo-wide (`grep -rl`), `мини-гриль` in 5 files - verified by reading `docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md` sections 1.1 and 3.1).
- Q5: `drone-acceptance | drone-coverage` -> `drone-acceptance | cycle-clerk` (major 2: `drone-coverage` is verbatim in the question line; replaced with `cycle-clerk`, the other agent file added in the same commit `7d243a9`, verified via `git show 7d243a9 --stat`).
- No two questions share a `refs:` entry (checked by hand across all five); `bash scripts/redact.sh` on the finished file diffs empty against the source.

## Findings
