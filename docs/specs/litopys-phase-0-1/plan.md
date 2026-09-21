# litopys phase 0-1: baseline + raw journal (plan)

**Tier:** 3 · **Spec slug:** `litopys-phase-0-1` · **Brief:** [brief.md](brief.md)
**Governed by:** grill `docs/grill/2026-09-21-project-memory-chronicle.md` (D1-D15, Act 2, Roadmap v2 phases 0-1); scout `recon/vulyk-hooks.md`; CLAUDE.md `## Profile` (bash-only, Windows Git Bash primary, no model calls in hooks)
**Depends on:** nothing - the repo holds two commits on `main` (VULYK 0.15.0 installed for its own development)

## Goal
Turn the empty `litopys` repo into a loadable Claude Code plugin that does two measurable things before any distillation exists. Phase 0: a model-free `bin/litopys append` writes dated chronicle lines into the host project's `docs/chronicle/YYYY-MM.md`; a `/litopys:recall` skill forks a sonnet agent over the host's git history and docs; five golden questions for VULYK are written from VULYK's own history before anything is distilled; `bin/litopys bench` runs them through recall and records hit/refs/tokens/seconds into `.litopys/baseline.jsonl`. Phase 1, only after the baseline number exists: four hooks write a raw per-session journal under `.litopys/raw/`, close it in under a second at SessionEnd, and inject a five-line banner at SessionStart. The phase closes with a report comparing one real ≥100k VULYK session's raw journal against `/export`, naming what the journal loses.

**Tier justification:** cross-cutting across every plugin surface (manifest, CLI, skill, agent, hooks, tests) plus a cross-repo measurement in VULYK; four contracts cross story boundaries; six stories over five waves.

## Assumptions
- **jq is the only parser.** Hooks and `bench` are pure bash + jq + git. Where jq is missing, the hooks exit 0 without writing, and SessionStart emits one static line saying the journal is disabled. No python anywhere, so VULYK's `pwd -W` guard is not needed. Rejected: a python fallback - two code paths for a spike.
- **`.litopys/` self-ignores.** Every writer creates `.litopys/.gitignore` containing `*` on first write, so no host project's `.gitignore` or CLAUDE.md is touched. The litopys repo's own `.gitignore` also lists `.litopys/`.
- **Golden questions are authored in this repo** at `examples/vulyk/golden-questions.md` (story 03 reads E:/Projects/vulyk read-only) and copied by the owner to `E:/Projects/vulyk/docs/chronicle/golden-questions.md` at the baseline gate, because `bench` reads the host project's `docs/chronicle/`. Keeps every story's diff inside this repo (scope-check, Law 3).
- **Bench drives recall through `claude -p`.** `bin/litopys bench` runs `claude -p --plugin-dir <root> --output-format json "/litopys:recall <question>"` from the host project's cwd, once per question. This is a CLI, not a hook, so a model call is allowed. Tests use a stub `claude` (env `LITOPYS_CLAUDE`) so the suite stays model-free. If print mode cannot invoke a forked plugin skill, the worker falls back to `claude -p --agent litopys:recall` and records which form worked in its story's Implementation notes.
- **Hit is deterministic.** `hit` = any `answer:` keyphrase of the question appears in the recall result (case-insensitive substring); `refs_matched` = count of expected refs found as substrings. No model judges the answer.
- **Baseline before hooks is a build gate.** Wave 4 is not dispatched until `E:/Projects/vulyk/.litopys/baseline.jsonl` holds five rows. The owner (or the Queen from a terminal) runs `bench` inside VULYK with `--plugin-dir E:/Projects/litopys` between waves 3 and 4.
- **Story 06 needs a human.** Someone must run one real VULYK session past 100k tokens with the plugin loaded, then `/export` it. The worker only compares and writes the report. Its verification is a `grep` on the report file, not a test from `## Commands` - there is no test to write for a document.
- **`UserPromptSubmit` field name.** The brief says `user_input`; the hook reads `.user_input // .prompt` so either official name works. Recon question for the scout: confirm the field name in `docs/en/hooks` and whether `/litopys:recall` is invocable in `claude -p`.
- **Chronicle notes pass through the host's `scripts/redact.sh`** when that file exists (VULYK hosts have it), else unredacted passthrough. Golden questions (story 03) are the other git-bound text: the worker pipes the finished file through `scripts/redact.sh` (present in this repo via VULYK) before returning, so every git-bound path this phase writes passes redact (Ask 7).
- **Plugin version** starts at `0.1.0` in `plugin.json`.
- **Ask 7's «ничего не пишется в CLAUDE.md» is read as a runtime constraint on the plugin** (no hook, CLI, skill or agent writes any project's CLAUDE.md), not as a freeze on this repo's own constitution, which the Queen edits as project paperwork (`## Commands` rows). Council seats judge the runtime reading.
- **Ask 6's comparison is journal vs `/export` only** (story 06 non-goal 1). The `.pty.log` sidecar the owner left beside the export is evidence about the terminal, not about either compared file; the report may keep it in a separate section but no `## Losses` item may rest on it. Fix round 2 story 09 enforces this reading; the Queen confirms it before dispatch if the owner meant the pty capture to count as "the export".

## Stories

**Wave 1**
- `litopys-phase-0-1-01-tracer-append` (opus, tracer) - manifest, `bin/litopys append`, `.gitignore`, `tests/append.test.sh`; loads with `--plugin-dir`.

**Wave 2** (blocked by 01)
- `litopys-phase-0-1-02-recall-skill` (sonnet) - `skills/recall/SKILL.md` + `agents/recall.md`, fork context, sonnet, answer-with-refs contract.
- `litopys-phase-0-1-03-golden-questions` (sonnet) - five VULYK questions with known answers and refs, authored in examples/vulyk/ from VULYK's history (read-only).

**Wave 3** (blocked by 01, 02, 03)
- `litopys-phase-0-1-04-bench` (opus) - `bin/litopys bench` -> `.litopys/baseline.jsonl`, stub-driven test.

**Gate:** baseline.jsonl with 5 rows exists in VULYK before wave 4.

**Wave 4** (blocked by 04)
- `litopys-phase-0-1-05-raw-journal-hooks` (opus) - `hooks/hooks.json`, `hooks/raw-journal.sh` (prompt/stop/end), `hooks/session-start.sh`, `tests/hooks.test.sh`.

**Wave 5** (blocked by 05, human session)
- `litopys-phase-0-1-06-raw-vs-export` (sonnet) - report `recon/raw-vs-export.md` with a named loss list.

**Wave 6 - fix round 1, Ask 4** (council RED at ac03fbe: seat opus, `tokens_in/tokens_out` = 0 on every real baseline row; lead-review majors 2, 3, 11 on the golden questions)
- `litopys-phase-0-1-07-bench-tokens` (opus, blocked by 04) - `bin/litopys` bench sums cache-inclusive token fields (revised C5), treats `is_error:true` as a failed call; stub + `tests/bench.test.sh` updated.
- `litopys-phase-0-1-08-golden-keyphrases` (sonnet, blocked by 03) - `examples/vulyk/golden-questions.md`: keyphrases that cannot match their own question, refs that are path-or-sha7 only, no keyphrase doubling as a ref.

**Gate after wave 6 (Queen, terminal):** re-copy `examples/vulyk/golden-questions.md` to `E:/Projects/vulyk/docs/chronicle/golden-questions.md`, re-run `bash E:/Projects/litopys/bin/litopys bench` inside E:/Projects/vulyk, confirm five new rows with non-zero `tokens_in`/`tokens_out`, then open round 2. **Run 2026-09-21 ~13:55Z, after wave 7 (round 2 critical 1): `hits 4/5 · refs 7/9 · 125s`, `tokens_in` 144k-260k and `tokens_out` 726-1661 per row; the round-1 rows moved to `E:/Projects/vulyk/.litopys/baseline.round1.jsonl`. Q4 missed because its keyphrases were not in the grill (round 2 major 2) - wave 8 fixes the file and the same gate runs once more before round 3.**

**Wave 7 - fix round 2, Ask 6** (council RED at 3c23c80: seat sonnet RED because `recon/raw-vs-export.md` is absent from the court; lead-review BLOCK, major 5: Losses 3-4 sourced from the `.pty.log`, not from the journal or `/export`)
- `litopys-phase-0-1-09-raw-vs-export-losses` (sonnet, blocked by 06) - `recon/raw-vs-export.md`: every `## Losses` item checkable in the two named files; pty-log observations moved to `## Outside the comparison (pty log)`; Header names the sidecar; Verdict reworded where it leaned on a pty-only loss.

**Wave 8 - fix round 2, lead-review majors 2-3 and minors 6-7 (cut by the Queen on the planner's hand-off in round 2)**
- `litopys-phase-0-1-10-golden-q4-q5` (sonnet, blocked by 08) - `examples/vulyk/golden-questions.md`: Q4 keyphrases literal in the adversarial grill, Q5 keyphrases true of the retired agent only, Q1 source/ref corrected; nothing sourced from `.litopys/`.

**Gate after wave 8 (Queen, terminal):** re-copy the file to `E:/Projects/vulyk/docs/chronicle/golden-questions.md`, re-run `bash E:/Projects/litopys/bin/litopys bench` in E:/Projects/vulyk, confirm five rows; that run is the phase-0 baseline. Then open round 3. **Run 2026-09-21 ~14:20Z after story 10: `hits 4/5 · refs 7/8 · 143s`, `tokens_in` 146k-370k, `tokens_out` 581-2179 per row, cost 0.11-0.19 USD; this is the phase-0 baseline in `E:/Projects/vulyk/.litopys/baseline.jsonl` (earlier runs kept as `baseline.round1.jsonl`, `baseline.round2.jsonl`). Q4 misses: recall's answer does not contain either grill keyphrase.**

Build agent count: 6 workers (3 opus, 3 sonnet) + full court (`council-sonnet`, `council-opus`, `council-haiku`) + `lead-review` = 10 agent dispatches, plus retries; fix round 1 adds 2 workers (1 opus, 1 sonnet) and one council round; fix round 2 adds 1 worker (sonnet) and one council round.

## Contracts

**C1 - project root and `.litopys/` dir (every story).** Root = `$CLAUDE_PROJECT_DIR` if a directory, else payload `cwd` (hooks), else `git rev-parse --show-toplevel`, else `$PWD`. Any writer of `.litopys/` first runs `mkdir -p .litopys && [ -f .litopys/.gitignore ] || printf '*\n' > .litopys/.gitignore`.

**C2 - `bin/litopys` CLI (01, 04).** `#!/usr/bin/env bash`, `set -u`, subcommand dispatch `append | bench | --version | help`. Skills and docs invoke it as `bash "${CLAUDE_PLUGIN_ROOT}/bin/litopys" <sub>` so Windows does not depend on PATH exec of an extension-less file. Test override: `LITOPYS_NOW=<UTC ISO>` replaces `date -u +%Y-%m-%dT%H:%M:%SZ`.

**C3 - chronicle line (01; read by nothing yet, mirrored from VULYK journal.sh).**
```
- 2026-09-21T12:34:56Z · <kind> · <ref> · <note>
```
- File `docs/chronicle/YYYY-MM.md` (month from the UTC ts), created with header `# Chronicle YYYY-MM` + blank line when absent.
- `kind` ∈ `grill|brief|verdict|ship|handoff|note`; anything else -> usage error, exit 2, nothing written.
- `ref` = path or sha as given; `note` = `--note` text with newlines collapsed to spaces, piped through `<root>/scripts/redact.sh` when present.
- Idempotent: if a line starting with `- <ts> · <kind> · <ref> · ` already exists, print it and write nothing.
- Prints the line to stdout; exit 0 always after argument validation (append is never a gate).

**C4 - golden questions file (03 writes, 08 corrects, 04 parses).** `docs/chronicle/golden-questions.md` in the host project:
```
# Golden questions - <project>
<!-- written <date>, before any distillation; sources: git log, CHANGELOG.md, docs/specs, docs/adr -->

## Q1 · <question, one line>
- answer: <keyphrase> | <alternative keyphrase>
- refs: <path or sha7>; <path or sha7>
- source: <where the answer was verified, one line>
```
Exactly five `## Q<n> ·` sections. `answer:` keyphrases are short distinctive strings (a version, a slug, an ADR id, a script name) - never a sentence, **never a substring of the question's own line, never identical to one of its refs, never a string present in nearly any host answer**. `refs:` semicolon-separated, at least one per question, **each a bare repo-relative path or sha7 - no `#anchor` or `[section]` suffix** - so a C6 `**Refs:**` line can contain it literally.

**C5 - `baseline.jsonl` row (04 writes, 07 corrects).** One JSON object per question per run, appended to `.litopys/baseline.jsonl`:
```
{"ts":"<UTC ISO>","project":"<basename of root>","q":"Q1","question":"...","hit":true,"refs_expected":2,"refs_matched":1,"tokens_in":12345,"tokens_out":678,"cost_usd":0.0123,"seconds":41,"model":"sonnet","litopys":"0.1.0"}
```
From `claude -p --output-format json`: `tokens_in` = `usage.input_tokens + usage.cache_creation_input_tokens + usage.cache_read_input_tokens` (missing fields count 0); `tokens_out` = `usage.output_tokens`; when the top-level `usage` sums to 0 but a per-model usage object is present, the same sums are taken over every model entry; `null` only when no usage object exists at all. `cost_usd` = `total_cost_usd` (`null` when absent). `seconds` is bench's own wall clock. `bench` prints one summary line `hits <n>/5 · refs <m>/<k> · <total seconds>s` and exits 0; a failed `claude` call - non-zero exit **or** exit 0 with `"is_error":true` - writes the row with `hit:false`, `refs_matched:0` and an `"error":"<first line>"` key. Rationale (round 1): `usage.input_tokens` alone is the uncached slice (2 tokens on a probe against 27k cache-creation + 24k cache-read), so a cache-blind column reads 0 on every real row and cannot serve D15's «phases 1-3 must exceed the baseline» or D12's ~5% ceiling.

**C6 - recall skill and agent (02 writes, 04 invokes).** `skills/recall/SKILL.md` frontmatter: `name: recall`, `description`, `context: fork`, `agent: recall`, `allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git tag:*), Bash(git show:*)`. `agents/recall.md` frontmatter: `name: recall`, `model: sonnet`, `tools: Read, Grep, Glob, Bash`. Search order fixed in the skill body: `docs/chronicle/`, `docs/specs/*/brief.md`, `docs/adr/`, `docs/grill/`, `CHANGELOG*`, `git tag`, `git log`. Return shape (the only thing that reaches the main context):
```
**Answer:** <≤10 lines>
**Refs:**
- <repo-relative path or sha7> - <why>
**Confidence:** high | medium | low
```

**C7 - hooks wiring (05).** `hooks/hooks.json`:
```json
{"hooks":{
 "UserPromptSubmit":[{"hooks":[{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/raw-journal.sh\" prompt","timeout":10}]}],
 "Stop":[{"hooks":[{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/raw-journal.sh\" stop","timeout":10}]}],
 "SessionEnd":[{"hooks":[{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/raw-journal.sh\" end"}]}],
 "SessionStart":[{"hooks":[{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\"","timeout":10}]}]
}}
```
SessionEnd carries no `timeout` - it must fit the default 1.5 s budget; the script does one `printf >>`. Every hook: read stdin JSON once with jq, exit 0 on any failure, never print to stdout except the SessionStart JSON. Skip Stop when `agent_id` is non-empty.

**C8 - raw journal file (05 writes, 06 reads).** `.litopys/raw/<session_id>.md`, created on first `prompt` or `stop`:
```
---
litopys: raw
version: 1
session_id: <id>
started: <UTC ISO>
cwd: <cwd from payload>
branch: <git branch or ->
---

## user · <UTC ISO>
<user_input verbatim>

## assistant · <UTC ISO>
<last_assistant_message verbatim>

## closed · <UTC ISO> · <reason>
```
`closed` is appended by SessionEnd only; a journal without a `## closed` line is open. "Unconsolidated" count for the banner = number of `.litopys/raw/*.md` files (no consolidation exists yet). No rotation, no cleanup, no redact (never enters git).

**C9 - SessionStart banner (05).** `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<5 lines>"}}` with exactly these lines:
```
[litopys] v0.1.0 · project chronicle
[litopys] chronicle: docs/chronicle/ (<n> files)
[litopys] last entry: <YYYY-MM-DD or none>
[litopys] raw journals: <n> unconsolidated in .litopys/raw/
[litopys] recall: /litopys:recall <question>
```
When jq is missing, one static line: `[litopys] jq not found - raw journal disabled`.

**C10 - raw-vs-export report sections (06 writes, 09 corrects).** `recon/raw-vs-export.md` holds, in order, `## Header`, `## Losses`, `## Kept`, `## Outside the comparison (pty log)`, `## Verdict`. Every `## Losses` item cites only the journal or the export file (a `grep` pattern or a line/block reference); anything sourced from the `.pty.log` sidecar lives under `## Outside the comparison` and nowhere else.

## Integration gate
`for t in tests/*.test.sh; do bash "$t" || exit 1; done && git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null && claude plugin validate .`
Before each dispatch: `bash scripts/wave-check.sh docs/specs/litopys-phase-0-1`.

## Tradeoffs
- **Separate hook scripts vs routing every event through `bin/litopys hook <event>`.** Chose separate scripts under `hooks/`: `bin/litopys` stays a user CLI with stdin free (VULYK's "hook modes read stdin, manual modes must not" bug). Rejected the single entry point - one file, but a CLI that sometimes blocks on stdin.
- **jq-required vs python fallback.** Chose jq-only with fail-open; VULYK's own `anomaly-scan.sh` already needs jq, so no host loses anything it had. Rejected python: doubles the code and reintroduces the `pwd -W` path bug.
- **Golden questions authored in litopys vs written straight into the VULYK repo.** Chose authoring in `examples/vulyk/` and a copy at the baseline gate: every story diff stays in this repo, so scope-check and Law 3 hold. `bench` keeps one rule (read the host project's `docs/chronicle/`). Rejected a cross-repo write: the scope gate would see an empty diff and the Queen would commit story output by hand.
- **Bench via `claude -p` with a stub in tests vs an in-session skill.** Chose the CLI: tokens, cost and duration are in the JSON output, and the run is reproducible from a terminal. Rejected an in-session `/litopys:bench` skill: no clean token count per question, and it would pollute the measuring session.
- **Fix round 1: cache-inclusive `tokens_in` vs adding separate cache columns.** Chose to fold cache creation + cache read into `tokens_in` and keep the C5 keys: the ask names one «токены» figure, D12's ceiling is about total spend, and every consumer (phase-2 comparison, the 5% check) wants one number. Rejected new `tokens_cache_*` keys: a wider row for phase 0 with no reader, and a baseline whose columns differ from what phase 2 will re-measure.
- **Fix round 1: two stories vs one.** Chose two: `bin/litopys`+fixtures (bash/JSON work, opus) and `examples/vulyk/golden-questions.md` (VULYK-history research, sonnet) share no file and no mental model, so the neighbour test fails and they run in parallel. Rejected one story: a worker fixing jq sums would re-derive five historical facts for no reason.
- **Fix round 2: move pty-log findings to their own section vs delete them.** Chose a separate `## Outside the comparison (pty log)` section: the observations (slash-command trace, terminal banner) are real phase-2 input and cost nothing to keep, while the ask's `## Losses` list becomes checkable in exactly the two files it names. Rejected deletion: it throws away verified evidence to satisfy a section boundary, and the next reader would rediscover it from the same sidecar.

## Descoped

- Review round 2 major 4 / round-1 major 5: `bin/litopys append --ref` containing a newline or the ` · ` separator is not normalised, so a multi-line ref writes a two-line record and defeats (ts, kind, ref) idempotence. Not in fix round 2 (Ask 6 only); the Queen decides between a wave-8 story on `bin/litopys` + `tests/append.test.sh` or a permanent descope line here.
- Review round 2 minors 6-13 and opus seat UNASKED (a)-(e), plus round-1 minors 9, 12, 13, 14: none named by round 2's unresolved-ask list; each needs either a story or a line here before round 3 - listed for the Queen, not cut by this planner.

- Review round 2 major 4 / round-1 major 5 (`append --ref` with a newline or ` · ` writes a two-line record): descoped to phase 2. In phase 0 every `--ref` comes from the plugin's own callers (skills, hooks, `journal.sh`-style one-liners); no user-facing path produces a multi-line ref. Phase 2's first `append` story normalises `--ref` the way `--note` is (collapse to one line) and adds the test.
- Review round 1 major 1 / planner's open question (bench sessions are journalled by the plugin's own hooks): decided - no env marker in phase 0/1 (it would touch Ask 5 files for a measurement-only case); phase 2's distiller skips `## user` blocks whose first line starts with `/litopys:recall`, and the banner's raw-journal count is accepted as including them until then.
- Review round 2 minors 8-11 and UNASKED (e) (bench: comment wording on the round-1 zeros, snake_case+camelCase summed, no test for all-zero top-level `usage`, unparsable stdout scored as a miss without an `error` key): descoped to a phase-2 bench-hardening story; the phase-0 number was produced by a run in which every `claude` call returned parsable JSON (all five rows carry `cost_usd` and `model`), so none of the four changes it.
- Review round 2 minor 12 = round-1 minors 9, 12, 13, 14: (9) `agents/recall.md` `tools: Bash` is what C6 specifies and the skill's `allowed-tools` is the narrower of the two by design - unchanged; (12) `hooks.test.sh` exercising only the non-`CLAUDE_PROJECT_DIR` rung - a phase-2 test story; (13) the `expect/refute/eq/bad` helpers copied into three test files - `tests/lib.sh` when a fourth test file appears; (14) the five remaining `.gitkeep` files are placeholders in still-empty or still-needed directories, removed at ship time if their directory is non-empty.
- Review round 2 minor 13 (an empty `**Council:**` template line above the RED lines): left in place - `cycle.sh`, `ship-check.sh` and the skills read the last `**Council:**` line (`tail -1`), and the template line is what `judge` appends after.
- UNASKED (a) `--strict` validate: resolved on 2026-09-21 by making the Profile's build command the non-strict `claude plugin validate .` (root CLAUDE.md warning is permanent, story 01 Findings). UNASKED (b) `append` idempotence keyed on (ts, kind, ref) to the second: by contract C3, mirrored from VULYK's `journal.sh`; a (kind, ref, note) key is a phase-2 contract change, recorded there. UNASKED (c) the copy of `examples/vulyk/golden-questions.md` into VULYK is the documented baseline gate, not an install step - a `/litopys:bench-init` skill is phase-2 material. UNASKED (d) redaction depends on the host's `scripts/redact.sh` - true and accepted for phase 0/1 (the first consumer is VULYK, which ships it); phase 2 bundles a fallback redactor in the plugin.

## Plan deltas

- 2026-09-21, round 1: the "baseline before hooks" gate was not held - wave 4 was built before `bench` ran in E:/Projects/vulyk (the gate watcher never started; `setsid` is absent in Git Bash). The baseline was measured afterwards, before story 06's session, so the raw journal never fed recall; the ordering intent (baseline uninfluenced by phase 1 output) holds, the wave order did not.
- 2026-09-21, round 1 -> wave 6: Ask 4's «токены» were not delivered in phase 0 as built (all real rows `tokens_in:0, tokens_out:0`); C5 revised, stories 07 and 08 cut, baseline to be re-run after wave 6 before round 2. The round-1 rows in `E:/Projects/vulyk/.litopys/baseline.jsonl` stay on disk as history but are not the phase-0 number.
- Open to the Queen (not in wave 6): bench sessions run through `claude -p` are journalled by the plugin's own hooks (review major 1) - the banner counts them and a phase-2 distiller would ingest them; decide whether bench sets an env marker the hooks honour (touches Ask 5 files) or whether phase 2 filters `## user` blocks that begin with `/litopys:recall`.
- 2026-09-21, round 2 -> wave 7: Ask 6 left unresolved. Story 09 cut (report only, C10 added). The wave-6 gate (re-copy golden questions, re-run bench in VULYK, confirm non-zero tokens) was promised "before round 2" and did not run (review critical 1); it is owed before round 3 and is a Queen terminal step, not a story. Two round-2 findings on Ask 6 have no story because they are not report defects: the sonnet seat's RED is court setup (`docs/specs/<slug>/` reduced to `brief.md`, so `recon/` is invisible to every seat) - either the court must carry `recon/raw-vs-export.md` or Ask 6 is judged by `lead-review` alone and the seats mark it N/A as opus and haiku did.
- 2026-09-21, round 2 -> wave 8: lead-review majors 2-3 and minors 6-7 (golden keyphrases not in their cited source; Q5 keyphrase names an added agent, not the retired one) had no story because the planner scoped wave 7 to Ask 6 and handed the rest to the Queen. The Queen cut story 10 (one file, sonnet) rather than descope: the golden file is the yardstick, and a wrong keyphrase makes the baseline number wrong, not merely unreviewed. The wave-6 gate ran after wave 7 (see the gate line) and runs again after wave 8.

**Approved:** Andrei, 2026-09-21 (in the vulyk session that ran the grill; build runs from a session inside E:/Projects/litopys)
**Briefed:**
**Branch:** vulyk/litopys-phase-0-1
**Checked:**
**Council:** RED round 1, 2026-09-21, at ac03fbe, pack ac71211211e9 - red: 4
**Council:** RED round 2, 2026-09-21, at ebda9de, pack e16ac0b7e26a - red: 6
**Council:** GREEN round 3, 2026-09-21, at 9cea6d0, pack ac0d2bda0834
**Shipped:**
