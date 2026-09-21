# Brief: litopys-phase-2-distill

**Date:** 2026-09-21 · **Tier:** 3 · **Deliverable:** changed code
**Governed by:** grill `docs/grill/2026-09-21-project-memory-chronicle.md` (D1-D15, Roadmap v2 phase 2); shipped spec `litopys-phase-0-1` (v0.1.0, council GREEN round 3); input document `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md`.

## Request (verbatim)

Owner, 2026-09-21, after the v0.1.0 ship report:
> Вот эти git push, run — это всё ты сам можешь делать. Почему ты меня заставляешь? Давай делай, всё делай и следующий бриф раскидывай на Wulic Plan. Давай, вперёд, погнали!

Roadmap v2 row the owner approved in the grill (2026-09-21):
> | 2 Дистилляция | agents/distiller sonnet; запись сессии = плоский файл с frontmatter (date, topics, links, source: live\|backfill); redact; коммит мимо рабочих веток; lock + cap N очереди; PreCompact-блок; повторный замер золотых вопросов vs baseline | delta vs baseline |

The next-brief draft the ship report handed over, which the owner sent to planning with the words above:

UNASKED lines, council round 3 of litopys-phase-0-1 (seat files, verbatim):
> UNASKED: `bin/litopys bench` genuinely calls the real `claude` binary five times per run (real API cost, ~40-55s and $0.18-0.27 each in this run) - expensive but matches the ask's intent; the bench run on the shipped golden-questions.md scored 4/5 hits (Q4 refs_matched 0) which is a baseline-quality signal, not a bug in the tool itself.
> UNASKED: `claude plugin validate . --strict` fails (root `CLAUDE.md` not loaded as plugin context) - project's own `CLAUDE.md` documents this as a deliberate, known non-strict-only result (line 157), not requested by any ask
> UNASKED: Three findings a careful owner would want. (1) Redaction is conditional on the *host* project owning scripts/redact.sh: in a scratch project without it, `append --note 'sk-ant-api03-AAAA...'` wrote the key verbatim into the git-tracked docs/chronicle/2026-09.md. VULYK and litopys both have the script, so ask 7 holds today, but the plugin is built to be dropped into any repo and ships no fallback filter of its own (e.g. $CLAUDE_PLUGIN_ROOT/scripts/redact.sh); `--ref` is never filtered at all. (2) COURT's own CLAUDE.md `## Commands` table now carries three story-scoped rows ("Story 03 shape check", "Story 08 keyphrase check", "Story 10 golden Q4/Q5 check", lines 148-150), each a grep over examples/vulyk/golden-questions.md. They are build bookkeeping, not product behaviour, so ask 7's runtime constraint is intact - but they are permanent config debt naming a spec that is ending, and the letter of «ничего не пишется в CLAUDE.md ни одного проекта» reads against them. (3) After `## closed`, a further prompt re-opens the same journal file and appends past the close marker (observed in my p2 probe) - harmless for resume, but the phase-2 consolidator will need a rule for journals with a close marker in the middle.

lead-review round 3, minor findings left open after the release commit (verbatim):
> 7. E:/Projects/litopys/docs/specs/litopys-phase-0-1/recon/raw-vs-export.md:25 (Kept 4) - worker - "the final prompt_input_exit line marks the interactive resume's end, matching the last user turn recorded in the export": the export's last user turn is turn 5 (journal `## closed · 12:49:25Z · other`, line 120); the 12:58:26Z interactive resume has no counterpart anywhere in the export (it held only /export and /exit, which the export omits). Story 09 reworded this sentence and it still leans on something the export does not contain. Condition: Kept 4 must say the resume's closing line has no export counterpart.
> 9. E:/Projects/litopys/docs/specs/litopys-phase-0-1/plan.md:134 (C8) + ## Descoped - plan - "a journal without a ## closed line is open" is already false on the real session: a10ea931's journal has six ## closed lines (one per -p -r exit plus the resume), so a resumed session is "closed" while it runs; the opus seat's UNASKED item (a second SessionEnd appends a second ## closed) is on no record. No runtime effect today (the banner counts files, not closed lines). Condition: amend C8 to say one ## closed per process exit, or record the deferral in ## Descoped.
> 10. E:/Projects/litopys/docs/specs/litopys-phase-0-1/litopys-phase-0-1-10-golden-q4-q5.md:88 + CLAUDE.md:150 - plan - story 10's verification asserts only that auto-ACCEPTED and cycle-clerk are absent and no CHANGELOG.md ref remains; the property the story exists for (each Q4 keyphrase literal in the grill) is mechanically checkable with `git -C E:/Projects/vulyk grep -F` and is not asserted, so a keyphrase the worker invented would pass green. Condition: a golden-file check must assert the source-literal property it was cut to enforce, or the plan must state that document stories get shape checks only.

`## Descoped` of docs/specs/litopys-phase-0-1/plan.md (verbatim):
> - Review round 2 major 4 / round-1 major 5 (`append --ref` with a newline or ` · ` writes a two-line record): descoped to phase 2. In phase 0 every `--ref` comes from the plugin's own callers (skills, hooks, `journal.sh`-style one-liners); no user-facing path produces a multi-line ref. Phase 2's first `append` story normalises `--ref` the way `--note` is (collapse to one line) and adds the test.
> - Review round 1 major 1 / planner's open question (bench sessions are journalled by the plugin's own hooks): decided - no env marker in phase 0/1 (it would touch Ask 5 files for a measurement-only case); phase 2's distiller skips `## user` blocks whose first line starts with `/litopys:recall`, and the banner's raw-journal count is accepted as including them until then.
> - Review round 2 minors 8-11 and UNASKED (e) (bench: comment wording on the round-1 zeros, snake_case+camelCase summed, no test for all-zero top-level `usage`, unparsable stdout scored as a miss without an `error` key): descoped to a phase-2 bench-hardening story; the phase-0 number was produced by a run in which every `claude` call returned parsable JSON (all five rows carry `cost_usd` and `model`), so none of the four changes it.
> - Review round 2 minor 12 = round-1 minors 9, 12, 13, 14: (9) `agents/recall.md` `tools: Bash` is what C6 specifies and the skill's `allowed-tools` is the narrower of the two by design - unchanged; (12) `hooks.test.sh` exercising only the non-`CLAUDE_PROJECT_DIR` rung - a phase-2 test story; (13) the `expect/refute/eq/bad` helpers copied into three test files - `tests/lib.sh` when a fourth test file appears; (14) the five remaining `.gitkeep` files are placeholders in still-empty or still-needed directories, removed at ship time if their directory is non-empty.
> - Review round 2 minor 13 (an empty `**Council:**` template line above the RED lines): left in place - `cycle.sh`, `ship-check.sh` and the skills read the last `**Council:**` line (`tail -1`), and the template line is what `judge` appends after.
> - UNASKED (a) `--strict` validate: resolved on 2026-09-21 by making the Profile's build command the non-strict `claude plugin validate .` (root CLAUDE.md warning is permanent, story 01 Findings). UNASKED (b) `append` idempotence keyed on (ts, kind, ref) to the second: by contract C3, mirrored from VULYK's `journal.sh`; a (kind, ref, note) key is a phase-2 contract change, recorded there. UNASKED (c) the copy of `examples/vulyk/golden-questions.md` into VULYK is the documented baseline gate, not an install step - a `/litopys:bench-init` skill is phase-2 material. UNASKED (d) redaction depends on the host's `scripts/redact.sh` - true and accepted for phase 0/1 (the first consumer is VULYK, which ships it); phase 2 bundles a fallback redactor in the plugin.

Phase-0 baseline to beat, recorded in plan.md of litopys-phase-0-1:
> `hits 4/5 · refs 7/8 · 143s`, `tokens_in` 146k-370k, `tokens_out` 581-2179 per row, cost 0.11-0.19 USD; this is the phase-0 baseline in `E:/Projects/vulyk/.litopys/baseline.jsonl`

Owner's standing constraints from the phase-0-1 brief (Ask 7 there), still binding:
> никаких вызовов claude -p или модели внутри хуков; SessionEnd-хук укладывается в 1 секунду; ничего не пишется в CLAUDE.md ни одного проекта; только sonnet для агента recall; всё, что идёт в git, проходит scripts/redact.sh

## Answers

Grill run by the Queen in ledger mode on the owner's standing authorisation ("Owner has authorised the Queen to answer routine grill questions from the grill ledger and the phase-0-1 plan"): each entry is the recommended option, its source decision named, `(assumed)` appended.

> 1. **Where a distilled session record lives and what it is** - `docs/chronicle/sessions/YYYY-MM-DD-<sid8>.md`, one flat markdown file per session with YAML frontmatter `date, session_id, topics, links, source: live|backfill, tokens, model`, plus one C3 line appended to `docs/chronicle/YYYY-MM.md` via `bin/litopys append --kind session --ref <that file>` so the monthly chronicle stays the index (D4 session = record, D13 one append command). Rejected: writing records only into the monthly file - a 100k session does not fit one line and recall needs a file to cite. (assumed)
> 2. **What triggers distillation** - never a model call inside a hook (Ask 7 of phase 0-1): a `/litopys:distill` skill with `context: fork` and a sonnet `distiller` agent does the work; the SessionStart hook only counts journals awaiting distillation and, past a threshold, says so in the banner (line 4 repurposed, still five lines, D6/D7); a new `PreCompact` hook appends a `## compact · <ts>` marker to the raw journal so the distiller knows a compaction happened (D11). Rejected: SessionStart spawning a detached `claude -p` - a model call started by a hook, the letter of Ask 7 reads against it, and the grill's own assumption ledger flags the file race. (assumed)
> 3. **How records reach git "мимо рабочих веток"** - the distiller writes the record and the chronicle line into the working tree and commits *only those paths* on the current branch (`git commit -- docs/chronicle/`), never touching staged or unstaged work outside `docs/chronicle/`; if the repo has no clean way to commit (detached HEAD, merge in progress, rebase) it leaves the files uncommitted and says so. Recall reads the working tree, so a separate branch would hide records from the very thing they exist for. Rejected: a dedicated `litopys/chronicle` branch via worktree - invisible to recall until merged, and a second branch for the owner to babysit. Surfaced as an assumption because it narrows the roadmap wording. (assumed)
> 4. **Lock and cap** - `mkdir .litopys/distill.lock` as the mutex (atomic on every shell), stale after 30 minutes; at most N=3 journals per run, oldest first, so a backlog of bench journals never eats a session start; journals whose first `## user` line starts with `/litopys:recall` or `/litopys:distill` are skipped and moved to `.litopys/raw/skipped/`, never distilled (D12 ~5% ceiling, ## Descoped of phase 0-1). (assumed)
> 5. **Redaction fallback** - the plugin ships `scripts/redact.sh`, VULYK's file copied verbatim with the caller names in the header changed; `append` and the distiller use the host's `scripts/redact.sh` when present, else the plugin's; `--ref` is collapsed to one line and passed through the same redactor as `--note`; a distilled record is redacted before it is written. Rejected: a Python redactor - a second implementation to keep in sync, the very problem VULYK's header comment names. (assumed)
> 6. **Measuring against the baseline** - `bin/litopys bench` keeps appending rows; a new `bench --delta` prints the latest run against the first five rows of `.litopys/baseline.jsonl` (hits, refs, seconds, tokens) so the phase's exit criterion "delta vs baseline" is one command; the golden questions themselves stay as shipped (D10, D15). Rejected: a separate `validate` command - that is phase 3's. (assumed)
> 7. **Confirmed requirement lines** - the `## Asks` below, derived from `## Request (verbatim)`; the build stops for approval after the plan (no `--go`). (assumed)

## Asks

1. `agents/distiller` sonnet; запись сессии = плоский файл с frontmatter (date, topics, links, source: live|backfill)
2. redact; коммит мимо рабочих веток; lock + cap N очереди
3. PreCompact-блок
4. повторный замер золотых вопросов vs baseline; выход: delta vs baseline
5. Redaction is conditional on the *host* project owning scripts/redact.sh ... the plugin is built to be dropped into any repo and ships no fallback filter of its own (e.g. $CLAUDE_PLUGIN_ROOT/scripts/redact.sh); `--ref` is never filtered at all.
6. `bin/litopys append --ref` containing a newline or the ` · ` separator is not normalised, so a multi-line ref writes a two-line record and defeats (ts, kind, ref) idempotence.
7. After `## closed`, a further prompt re-opens the same journal file and appends past the close marker ... the phase-2 consolidator will need a rule for journals with a close marker in the middle.
8. phase 2's distiller skips `## user` blocks whose first line starts with `/litopys:recall`
9. bench: comment wording on the round-1 zeros, snake_case+camelCase summed, no test for all-zero top-level `usage`, unparsable stdout scored as a miss without an `error` key
10. никаких вызовов claude -p или модели внутри хуков; SessionEnd-хук укладывается в 1 секунду; ничего не пишется в CLAUDE.md ни одного проекта; только sonnet для агента recall; всё, что идёт в git, проходит scripts/redact.sh

## Asks (verbatim quotes for trace-check)
> 1. `agents/distiller` sonnet; запись сессии = плоский файл с frontmatter (date, topics, links, source: live|backfill)
> 2. redact; коммит мимо рабочих веток; lock + cap N очереди
> 3. PreCompact-блок
> 4. повторный замер золотых вопросов vs baseline; выход: delta vs baseline
> 5. Redaction is conditional on the *host* project owning scripts/redact.sh ... the plugin is built to be dropped into any repo and ships no fallback filter of its own (e.g. $CLAUDE_PLUGIN_ROOT/scripts/redact.sh); `--ref` is never filtered at all.
> 6. `bin/litopys append --ref` containing a newline or the ` · ` separator is not normalised, so a multi-line ref writes a two-line record and defeats (ts, kind, ref) idempotence.
> 7. After `## closed`, a further prompt re-opens the same journal file and appends past the close marker ... the phase-2 consolidator will need a rule for journals with a close marker in the middle.
> 8. phase 2's distiller skips `## user` blocks whose first line starts with `/litopys:recall`
> 9. bench: comment wording on the round-1 zeros, snake_case+camelCase summed, no test for all-zero top-level `usage`, unparsable stdout scored as a miss without an `error` key
> 10. никаких вызовов claude -p или модели внутри хуков; SessionEnd-хук укладывается в 1 секунду; ничего не пишется в CLAUDE.md ни одного проекта; только sonnet для агента recall; всё, что идёт в git, проходит scripts/redact.sh
