---
story: litopys-phase-0-1-04
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 3
blocked_by: [litopys-phase-0-1-01, litopys-phase-0-1-02, litopys-phase-0-1-03]
---

# `bin/litopys bench`: golden questions through recall into baseline.jsonl

## Goal
After this story `bash bin/litopys bench`, run from a host project with the plugin loadable, reads that project's `docs/chronicle/golden-questions.md`, asks each question through `/litopys:recall` via `claude -p`, and appends one C5 row per question to `.litopys/baseline.jsonl` with hit, refs matched, tokens, cost and seconds. This produces the phase 0 baseline number that phases 1-3 must beat. The test drives it with a stub `claude` so the suite never calls a model.

## Requirements
> `bin/litopys bench` прогоняет их через recall и пишет `.litopys/baseline.jsonl` (вопрос, попадание да/нет, ссылки совпали, токены, секунды).
> Базовая линия «append + recall по тому, что уже есть» меряется ПЕРВОЙ, в фазе 0;

## Files
- bin/litopys
- tests/bench.test.sh
- tests/fixtures/claude-stub.sh
- tests/fixtures/golden-questions.md

## Non-goals
- Do not change `append` (story 01) beyond adding the `bench` case to the dispatcher and sharing the C1 root helper.
- Do not judge answers with a model; hit and refs_matched are substring rules (plan assumptions).
- Do not add `--questions`, `--project`, `--model` or any flag; cwd is the project, sonnet is the model, `.litopys/baseline.jsonl` is the output.
- Do not run the real bench in E:/Projects/vulyk from inside the build - the Queen or owner does that after the story closes (plan gate before wave 4).
- Do not write hooks or touch `hooks/`.

## Map slice
Contracts C1, C2, C4, C5, C6 in plan.md. `recon/vulyk-hooks.md` "manual modes must NOT read stdin" gotcha. Plan assumption "Bench drives recall through `claude -p`" including the `--agent litopys:recall` fallback.

## Acceptance criteria
- [ ] `bench` resolves the plugin root as `${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}` and invokes `${LITOPYS_CLAUDE:-claude} -p --plugin-dir "<root>" --model sonnet --output-format json "/litopys:recall <question>"` once per question, with cwd = project root, capturing stdout, exit code and wall-clock seconds.
- [ ] Parses C4: five `## Q<n> ·` sections, `answer:` split on `|`, `refs:` split on `;`; a malformed file prints one stderr line and exits 2 with nothing written.
- [ ] Row per question exactly as C5; `hit` true iff any answer keyphrase is a case-insensitive substring of the JSON `result` text; `refs_matched` counts expected refs found as substrings; `tokens_in`/`tokens_out`/`cost_usd` from `usage.input_tokens`, `usage.output_tokens`, `total_cost_usd`, `null` when absent; a non-zero `claude` exit yields `hit:false` plus an `error` key.
- [ ] Ensures `.litopys/.gitignore` with `*` before writing (C1). Prints the one-line summary from C5 and exits 0.
- [ ] `bench` never reads stdin (a terminal run with an open pipe must not block).
- [ ] `tests/bench.test.sh` copies `tests/fixtures/golden-questions.md` into a temp project, points `LITOPYS_CLAUDE` at `tests/fixtures/claude-stub.sh` (which echoes canned `--output-format json` payloads: one answer hitting with 2 refs, one missing, one exit 1), and asserts 5 rows, the hit/refs/error fields, the self-ignoring `.litopys/.gitignore`, and that a second run appends 5 more rows.
- [ ] Manual run recorded in Implementation notes: in E:/Projects/vulyk, `bash E:/Projects/litopys/bin/litopys bench` produces 5 real rows; note the summary line and which invocation form (`/litopys:recall` vs `--agent`) worked.

## Verification
`bash tests/bench.test.sh`

## Implementation notes
- `bin/litopys`: `cmd_bench` + a `trim` helper added; dispatcher `bench)` now calls it. `append` untouched, `project_root` (C1) shared as planned.
- Parser is pure bash string ops over the C4 file; jq is used only for reading claude's JSON and for building each row (`jq -cn --argjson ...`), so a row can never be malformed JSON. `bench` exits 2 with one stderr line when jq is absent.
- Manual mode discipline: `bench` reads no stdin and passes `< /dev/null` to the `claude` child; `tests/bench.test.sh` proves it with a fifo whose writer stays open (fails the assertion after 10s rather than hanging forever).
- Fixture stub logs `cwd` + argv to `$LITOPYS_STUB_LOG`, which is how the test asserts the exact invocation form (`-p --plugin-dir <root> --model sonnet --output-format json "/litopys:recall <q>"`) and that cwd is the project root.
- `tests/fixtures/claude-stub.sh` is mode 100755 in the git index (`git update-index --chmod=+x`) - `bench` execs it directly, so a clone on Linux needs the bit.
- Summary on the fixture is `hits 3/5 · refs 5/8` (Q1/Q2/Q5 hit, Q3 miss, Q4 = stub exit 1 -> `hit:false` + `error`), not 4/5: a failed call is never a hit.
- **AC 7 (manual run in E:/Projects/vulyk) not performed.** It contradicts Non-goal 4 ("Do not run the real bench in E:/Projects/vulyk from inside the build - the Queen or owner does that after the story closes"), and the prerequisite does not exist: `E:/Projects/vulyk/docs/chronicle/` is absent, so the owner has not yet copied `examples/vulyk/golden-questions.md` there. Which invocation form works against a real `claude` (slash command vs `--agent litopys:recall` fallback) is therefore still unverified - it is the baseline gate's first question.

## Findings
- Open question for the planner/Queen: AC 7 and Non-goal 4 of this story ask for opposite things. Resolved in favour of the Non-goal (the plan's wave-3/4 gate also assigns the real run to the owner). If the slash form fails in `claude -p`, the one-line change is the invocation in `cmd_bench` plus the `slash command form` assertion in `tests/bench.test.sh`.
- Queen note after the real run (2026-09-21, E:/Projects/vulyk): `hits 5/5 · refs 7/9 · 140s`, 5 rows, slash-command form worked. Every row has `tokens_in: 0`, `tokens_out: 0` while `cost_usd` is non-zero: `usage.input_tokens` in `claude -p` JSON is the uncached slice only (2 tokens in a probe); the bulk sits in `cache_creation_input_tokens`/`cache_read_input_tokens`. bench implements C5 as written; C5 itself needs the cache fields in phase 2.
