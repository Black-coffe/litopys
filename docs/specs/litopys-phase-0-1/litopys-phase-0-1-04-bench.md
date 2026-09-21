---
story: litopys-phase-0-1-04
spec: litopys-phase-0-1
status: todo
returned:
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

## Findings
