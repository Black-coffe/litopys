<!-- seat: review · model: unknown · round: 1 · head: 6d29194 · pack: ac71211211e9 · attempt: 1 · recorded: 2026-09-21T13:21:59Z · verdict: PASS -->
VERDICT: PASS

Adversarial review, litopys-phase-0-1, round 1. Diff 4675af7..6d29194 (branch vulyk/litopys-phase-0-1), six stories, all status done. No critical finding; several majors the Queen should route before phase 2 leans on the baseline. Verification I ran (not the suite): bin/litopys append with a newline inside --ref in a mktemp project; ls/grep/wc over E:/Projects/vulyk/.litopys (baseline.jsonl, raw/, export file, pty log) to check the claims in stories 04 and 06 and the report.

## Scope
- Story commits (5e30847, 3898269, b0674a0, 41b2ca5, 74b920c, ac03fbe) touch only their ## Files plus the story file and memory/stats/*.jsonl (cycle runtime) - no Law 3 violation inside the stories. memory/stats/scope.jsonl out_of_scope counts (e.g. story 02: declared 2, changed 9) are inflated by Queen chores in the same window, not by the workers.
- Queen chore commits (3013deb, 5fa5ea7, 94d1fcc, 908c9f1) edit CLAUDE.md ## Commands - see minor finding 8 (Ask 7 literal reading).
- The dispatch names docs/adr/001-cycle-state-contract.md; docs/adr/ and docs/wiki/ are empty in this repo (the ADR lives in E:/Projects/vulyk). No recorded invariants to check here; .claude/rules/example-api.md is the installer sample and does not apply.

## Major

1. E:/Projects/litopys/bin/litopys:200 + E:/Projects/litopys/hooks/hooks.json:2-3 - plan - bench sessions must not be journaled as raw sessions of the host project: bench runs claude -p --plugin-dir <root>, which loads the plugin's own UserPromptSubmit/Stop/SessionEnd hooks, so every bench question leaves a .litopys/raw/<id>.md in the host (verified: E:/Projects/vulyk/.litopys/raw/ holds five journals stamped 12:42-12:44Z - 2dbc4bb0, 3fdcf87f, 898030b6, a1c8582d, e86ba3a1 - each opening with a "## user" block equal to "/litopys:recall <golden question>"). The banner count is inflated (6 unconsolidated in VULYK, one real) and the phase 2 distiller would ingest recall's own answers to the golden questions, feeding the yardstick back into the corpus it measures. Neither the plan assumption "Bench drives recall through claude -p" nor story 04/05 mentions it.

2. E:/Projects/litopys/examples/vulyk/golden-questions.md:11,16,21,26 - worker - every answer: keyphrase must be absent from its own question and not ubiquitous in the host: Q3 "ADR-001", Q4 "stage 05" and "adversarial", Q5 "drone-coverage" all appear verbatim in their question, and Q2 "brief.md" occurs in nearly any VULYK answer, so an answer that merely restates the question (or a "not found" that quotes it) scores hit:true. Story 03 AC 4 asks exactly for this ("must not fire on an unrelated answer"); the recorded baseline is already saturated at hits 5/5, which leaves phases 1-3 nothing to exceed on the hit axis (brief A2/D15).

3. E:/Projects/litopys/examples/vulyk/golden-questions.md:7 - worker - every refs: entry must be a repo-relative path or sha7 that a C6-shaped answer can contain: "CHANGELOG.md#[0.2.0]" is neither, can never be a substring of a **Refs:** list, and permanently costs Q1 one ref (baseline row Q1: refs_matched 2 of 3). C4 says "path or sha7".

4. E:/Projects/litopys/docs/specs/litopys-phase-0-1/plan.md:74-78,140-144 + E:/Projects/litopys/docs/specs/litopys-phase-0-1/litopys-phase-0-1-04-bench.md:247 - plan - the baseline must record a token figure that measures something, or the plan must record in ## Descoped / ## Plan deltas that Ask 4's tokens are not delivered in phase 0: all five real rows carry tokens_in:0, tokens_out:0 (verified in E:/Projects/vulyk/.litopys/baseline.jsonl) while cost_usd is 0.12-0.23. This is recorded only as a Queen note in story 04's Findings; both plan sections are empty. The offered explanation (uncached slice in usage.input_tokens) does not account for output_tokens = 0 and is unverified - invented-fact risk.

5. E:/Projects/litopys/bin/litopys:99-108 - worker - --ref must be normalised to one line (and the C3 separator kept out of it) before it becomes part of the record prefix: a ref containing a newline writes a two-line record and defeats idempotence (reproduced in a mktemp project: two identical appends with LITOPYS_NOW fixed produce 2 records / 6 lines). Only --note is collapsed (line 91); C3's "one record = one line" and "idempotent on (ts, kind, ref)" both break, and the chronicle is the one git-bound artifact this phase writes.

6. E:/Projects/litopys/docs/specs/litopys-phase-0-1/recon/raw-vs-export.md:73-74 - worker - every item under ## Losses must be checkable in the two named files: Loss 3 (/export, /exit command echo) and most of Loss 4 (resume hint, /effort, permission mode, 128.1k/1.0M readout) are sourced from export-a10ea931.md.pty.log, a terminal capture that is neither the journal nor /export; grep over E:/Projects/vulyk/.litopys/export-a10ea931.md finds none of them (only the three-line banner at lines 1-3). Story 06 non-goal 1 and AC 5 restrict the comparison to journal vs /export. Header counts (122/184 lines, 5/5/6 blocks, 5 user / 6 assistant export blocks) verified correct.

## Minor

7. E:/Projects/litopys/docs/specs/litopys-phase-0-1/plan.md:18,36,144 + journal.md:6 - plan - the "baseline before hooks" gate was not held (wave 4 built before bench ran; journal says the gate watcher never ran because setsid is absent in Git Bash) and ## Plan deltas is still empty; the deviation must be on the plan record, not only in the journal.

8. E:/Projects/litopys/CLAUDE.md:145-149,154 - plan - Ask 7 says literally that nothing is written to the CLAUDE.md of any project; the Queen's chore commits added five rows to this repo's CLAUDE.md ## Commands and relaxed the validate cell. The intent (plugin runtime never writes a host CLAUDE.md) holds, but a blind seat reading the ask as written will flag it; the plan should state the reading it takes.

9. E:/Projects/litopys/agents/recall.md:5 vs E:/Projects/litopys/skills/recall/SKILL.md:6 - plan - the agent runs with unrestricted Bash while the skill's allowed-tools limits Bash to git log/tag/show; when a skill forks into a named agent the agent's frontmatter is what the fork actually gets, so the git-only restriction is prose only. C6 dictated both lists; the plan should either narrow the agent's tools or record why unrestricted Bash is accepted for a read-only recall.

10. E:/Projects/litopys/bin/litopys:217 - worker - a claude -p reply with exit 0 but "is_error":true must be treated as a failed call (row with hit:false + error), not scored as an answer; today only the process exit code decides.

11. E:/Projects/litopys/examples/vulyk/golden-questions.md:6-7 - worker - Q1 uses the same string (docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md) as both a keyphrase and a ref, so a ref match implies a hit for Q1; hit and refs should measure different things.

12. E:/Projects/litopys/tests/hooks.test.sh:43 - worker - the real hook environment always has CLAUDE_PROJECT_DIR set (the first C1 rung, raw-journal.sh:43-44 and session-start.sh:26-27); the test unsets it and only exercises the payload-cwd rung, so the production path is covered by the manual check alone. One case with CLAUDE_PROJECT_DIR set (and a Windows-style backslash path) would close that.

13. E:/Projects/litopys/tests/append.test.sh:21-35, tests/bench.test.sh:21-39, tests/hooks.test.sh:21-38 - plan - expect/refute/eq/bad are copied verbatim into three files; a shared tests/lib.sh would keep future fixes to one place. Matches "VULYK style", so a plan call, not a worker miss.

14. Repo root (.claude-plugin/.gitkeep, bin/.gitkeep, hooks/.gitkeep, tests/fixtures/.gitkeep, examples/vulyk/.gitkeep) - plan - commit 30e94ec "drop placeholder .gitkeep files" removed two of seven; the remaining five sit beside real files.

15. E:/Projects/litopys/bin/litopys:241-246 - worker - cost_usd is re-serialised through jq tostring and lands as 0.11645360000000002; rounding to 6 decimals (or passing the raw JSON number through) keeps the ledger readable. Cosmetic.

## Checked and clean
- Test theater: append.test.sh, bench.test.sh, hooks.test.sh assert on-disk content, stdout, exit codes and stub argv; each named behaviour (idempotence, redact masking, agent_id skip, five-line banner, one-write end, malformed C4 -> exit 2, stdin non-blocking) would fail its assertion if removed. Story 01's "seven mutations, seven reds" claim maps to concrete assertions at append.test.sh:60, 78, 73, 53, 94-96, 98-99, 110.
- hooks/hooks.json is byte-for-byte C7; SessionEnd has no timeout; journal_end is one >>.
- Session id is sanitised to [A-Za-z0-9._-] before becoming a filename (raw-journal.sh:38) - no path traversal.
- No secrets in the diff; golden questions passed through scripts/redact.sh (story 03 notes, empty diff).
- No reinvention: project_root, trim, the C4 parser and the hooks have no prior equivalent in this repo.
