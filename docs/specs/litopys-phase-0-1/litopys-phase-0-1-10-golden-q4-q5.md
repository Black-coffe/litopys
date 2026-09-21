---
story: litopys-phase-0-1-10
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 8
blocked_by: [litopys-phase-0-1-08]
---

# Fix round 2 / lead-review majors 2-3, minors 6-7: golden keyphrases that exist in their cited source and name the answer

## Goal
After this story `examples/vulyk/golden-questions.md` holds the same five questions, but Q4's keyphrases are literal strings of `docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md`, Q5's keyphrases are all true of the *retired* agent, Q1's `source:` line says where "subtraction" really lives, and Q1's changelog ref is a sha7 rather than the bare `CHANGELOG.md`. No keyphrase anywhere is sourced from a `.litopys/` file.

## Requirements
> `docs/chronicle/golden-questions.md` для VULYK: 5 вопросов с известным ответом и ссылкой (среди них «что было в релизе до 0.1, как брейнштормили, что устарело»), записанных до любой дистилляции;
> Базовая линия «append + recall по тому, что уже есть» меряется ПЕРВОЙ, в фазе 0; фазы 1-3 оправдываются только её превышением (A2, D15).

## Files
- examples/vulyk/golden-questions.md

## Non-goals
- Do not change which five facts are asked, the Q1 wording, or the C4 shape; only `answer:`, `refs:` and `source:` lines of Q1, Q4, Q5 move. Q2 and Q3 stay as they are.
- Do not write into E:/Projects/vulyk or copy the file there; the Queen re-copies it and re-runs bench.
- Do not read anything under `E:/Projects/vulyk/.litopys/` (raw journals of earlier bench runs contain recall's own answers; sourcing a keyphrase from them is the loop review round 2 major 2 names).
- Do not run `bench` or `recall`; verify with `git grep`, `git show`, `git log -S` and reading the cited file in E:/Projects/vulyk.
- Do not touch `bin/litopys`, `tests/`, `tests/fixtures/golden-questions.md`.

## Map slice
Contract C4 in plan.md. `council/round-2/review.md` majors 2, 3 and minors 6, 7 (the conditions below are theirs). Story 08 Implementation notes for the previous keyphrase choices.

## Acceptance criteria
- [ ] Q4: each `answer:` keyphrase is a literal, case-sensitive substring of `docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md` in E:/Projects/vulyk (`git grep -F -- '<keyphrase>' -- docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md` non-empty), is not a substring of the Q4 question line, and is not a string nearly any VULYK answer contains; `source:` quotes the grill sentence it comes from.
- [ ] Q5: every `answer:` keyphrase is true of the retired agent only - a second spelling of `drone-acceptance`, the story slug `autonomous-cycle-05`, or the sha7 `7d243a9` - so that an answer naming only `cycle-clerk` cannot score `hit:true`; `cycle-clerk` is gone from the file.
- [ ] Q1: `source:` names where "subtraction" actually occurs (commit message of `1a55780`, reachable via `git log`), and the `refs:` entry `CHANGELOG.md` is replaced by a sha7 or the grill path so Q1 carries no near-free ref point; still no two questions share a ref.
- [ ] Every keyphrase in the file was verified by a `git grep`/`git show` command against tracked VULYK files, and Implementation notes list, per changed question, old -> new plus the exact command that verified each new keyphrase.
- [ ] Still exactly five `## Q<n> ·` sections with `- answer:`, `- refs:`, `- source:`; no `#anchor` or `[section]` in refs; `bash scripts/redact.sh` over the file diffs empty.

## Verification
`grep -c '^## Q[1-5] · ' examples/vulyk/golden-questions.md | grep -qx 5 && ! grep -qi 'auto-ACCEPTED\|cycle-clerk' examples/vulyk/golden-questions.md && ! grep -E '^- refs: .*[#\[]' examples/vulyk/golden-questions.md && ! grep -E '^- refs: CHANGELOG.md' examples/vulyk/golden-questions.md`

## Implementation notes
- Touched only `examples/vulyk/golden-questions.md`; every keyphrase re-verified read-only against E:/Projects/vulyk tracked files (no `.litopys/` reads, no `bench`/`recall` run).
- Q1 refs: `CHANGELOG.md; 1a55780; docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md` -> `1a55780; docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md` (dropped the bare `CHANGELOG.md` ref per major/minor 7 - a Q1 answer citing the changelog at all would have matched it; `1a55780` already covers the CHANGELOG fact via `git show`). Verified: `git grep -E '^- refs: CHANGELOG.md' examples/vulyk/golden-questions.md` now empty.
- Q1 `source:` corrected (minor 6): previously attributed "subtraction" to the grill file, but the grill (`docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md`) only says «вычитание» - the English word occurs solely in the `1a55780` commit message. New source names that. Verified with `cd E:/Projects/vulyk && git show -s --format='%B' 1a55780` (body contains "a breaking subtraction") and `git grep -F -- subtraction -- '*'` (only hits: the `1a55780` commit via `git log -S`, and `memory/learnings/2026-07-27-opus-5-migration.md`; not the grill). `answer:` keyphrases (`v0.1.0 | subtraction | additive`) unchanged - only `refs:`/`source:` moved, per Non-goals.
- Q4 `answer:` `auto-ACCEPTED | мини-гриль` -> `no owner response by | мини-гриль` (major 2: `auto-ACCEPTED` occurred in no tracked VULYK file - it was sourced from a `.litopys/raw/` journal, banned by Non-goals). Verified new keyphrase with `cd E:/Projects/vulyk && git grep -nF -- 'no owner response by' -- docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md` (hit, line 61, the deadline proposal in section 3.1) and `git grep -lF -- 'no owner response by'` (only that one file, repo-wide). `мини-гриль` kept - review's "Checked and clean" section already confirmed it is literal in the grill and not ubiquitous (5 files). `source:` rewritten to quote the actual grill sentence («Первое: `human-check.sh` получает дедлайн ... auto, no owner response by <ts>») instead of the fabricated `auto-ACCEPTED` phrase.
- Q5 `answer:` `drone-acceptance | cycle-clerk` -> `drone-acceptance.md | autonomous-cycle-05` (major 3: `cycle-clerk` is an agent ADDED in commit `7d243a9`, not the retired one - an answer naming only `cycle-clerk` was scoring `hit:true` for the wrong agent). Verified `drone-acceptance.md`: `cd E:/Projects/vulyk && git show 7d243a9 --stat` shows `.claude/agents/drone-acceptance.md | 82 ----` deleted-only in that commit. Verified `autonomous-cycle-05`: `git grep -lF -- 'autonomous-cycle-05'` lists `docs/specs/autonomous-cycle/autonomous-cycle-05-council-agents.md` (the story that retires the agent) among others; neither string is a substring of the Q5 question line. `cycle-clerk` removed from both `answer:` and `source:` lines (grep confirms it is now absent from the whole file).
- `bash scripts/redact.sh < examples/vulyk/golden-questions.md` diffs empty against the file. File written/edited with LF-only line endings throughout (`grep -c $'\r' examples/vulyk/golden-questions.md` = 0).

## Findings
