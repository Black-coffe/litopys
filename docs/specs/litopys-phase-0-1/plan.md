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

Build agent count: 6 workers (3 opus, 3 sonnet) + full court (`council-sonnet`, `council-opus`, `council-haiku`) + `lead-review` = 10 agent dispatches, plus retries.

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

**C4 - golden questions file (03 writes, 04 parses).** `docs/chronicle/golden-questions.md` in the host project:
```
# Golden questions - <project>
<!-- written <date>, before any distillation; sources: git log, CHANGELOG.md, docs/specs, docs/adr -->

## Q1 · <question, one line>
- answer: <keyphrase> | <alternative keyphrase>
- refs: <path or sha7>; <path or sha7>
- source: <where the answer was verified, one line>
```
Exactly five `## Q<n> ·` sections. `answer:` keyphrases are short distinctive strings (a version, a slug, an ADR id) - never a sentence. `refs:` semicolon-separated, at least one per question.

**C5 - `baseline.jsonl` row (04 writes).** One JSON object per question per run, appended to `.litopys/baseline.jsonl`:
```
{"ts":"<UTC ISO>","project":"<basename of root>","q":"Q1","question":"...","hit":true,"refs_expected":2,"refs_matched":1,"tokens_in":12345,"tokens_out":678,"cost_usd":0.0123,"seconds":41,"model":"sonnet","litopys":"0.1.0"}
```
`tokens_*` and `cost_usd` come from `claude -p --output-format json` (`usage.input_tokens`, `usage.output_tokens`, `total_cost_usd`; `null` when absent). `seconds` is bench's own wall clock. `bench` prints one summary line `hits <n>/5 · refs <m>/<k> · <total seconds>s` and exits 0; a failed `claude` call writes the row with `hit:false` and an `"error":"<first line>"` key.

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

## Integration gate
`for t in tests/*.test.sh; do bash "$t" || exit 1; done && git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null && claude plugin validate .`
Before each dispatch: `bash scripts/wave-check.sh docs/specs/litopys-phase-0-1`.

## Tradeoffs
- **Separate hook scripts vs routing every event through `bin/litopys hook <event>`.** Chose separate scripts under `hooks/`: `bin/litopys` stays a user CLI with stdin free (VULYK's "hook modes read stdin, manual modes must not" bug). Rejected the single entry point - one file, but a CLI that sometimes blocks on stdin.
- **jq-required vs python fallback.** Chose jq-only with fail-open; VULYK's own `anomaly-scan.sh` already needs jq, so no host loses anything it had. Rejected python: doubles the code and reintroduces the `pwd -W` path bug.
- **Golden questions authored in litopys vs written straight into the VULYK repo.** Chose authoring in `examples/vulyk/` and a copy at the baseline gate: every story diff stays in this repo, so scope-check and Law 3 hold. `bench` keeps one rule (read the host project's `docs/chronicle/`). Rejected a cross-repo write: the scope gate would see an empty diff and the Queen would commit story output by hand.
- **Bench via `claude -p` with a stub in tests vs an in-session skill.** Chose the CLI: tokens, cost and duration are in the JSON output, and the run is reproducible from a terminal. Rejected an in-session `/litopys:bench` skill: no clean token count per question, and it would pollute the measuring session.

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-09-21 (in the vulyk session that ran the grill; build runs from a session inside E:/Projects/litopys)
**Briefed:**
**Branch:** vulyk/litopys-phase-0-1
**Checked:**
**Council:**
**Shipped:**
