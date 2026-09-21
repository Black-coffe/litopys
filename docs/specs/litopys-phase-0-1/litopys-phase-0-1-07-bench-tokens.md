---
story: litopys-phase-0-1-07
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 6
blocked_by: [litopys-phase-0-1-04]
---

# Fix round 1 / Ask 4: `bench` records real token counts and treats `is_error` as a failed call

## Goal
After this story every row `bin/litopys bench` appends to `.litopys/baseline.jsonl` carries non-zero `tokens_in` / `tokens_out` on a real run, because bench sums every input-side token field `claude -p --output-format json` reports (uncached input, cache creation, cache read) instead of the uncached slice alone; and a reply whose JSON says `"is_error":true` is scored as a failed call (`hit:false` + `error`), not as an answer. Council round 1 (seat opus, RED on Ask 4): all five real rows in E:/Projects/vulyk read `tokens_in:0, tokens_out:0` while `cost_usd` was 0.12-0.23, so the «токены» column of the phase-0 baseline measured nothing.

## Requirements
> `bin/litopys bench` прогоняет их через recall и пишет `.litopys/baseline.jsonl` (вопрос, попадание да/нет, ссылки совпали, токены, секунды).
> Базовая линия «append + recall по тому, что уже есть» меряется ПЕРВОЙ, в фазе 0; фазы 1-3 оправдываются только её превышением (A2, D15).

## Files
- bin/litopys
- tests/bench.test.sh
- tests/fixtures/claude-stub.sh

## Non-goals
- Do not touch `append`, `hooks/`, `skills/`, `agents/` or `examples/vulyk/golden-questions.md` (story 08 owns the questions).
- Do not add a `--tokens-from` flag, a second output file or a per-model breakdown; the C5 row keeps its keys, only the numbers become true.
- Do not stop bench sessions from being journalled by the raw hooks (review major 1) - that is a hooks decision the Queen routes separately.
- Do not re-run the real bench in E:/Projects/vulyk from inside the build; the Queen does that after the story closes and the golden questions are re-copied.
- Do not round or reformat `cost_usd`.

## Map slice
Contract C5 (revised in plan.md, this round) and the round-1 seat report `council/round-1/opus.md` ASK 4 line, which shows the live `.usage` shape: `input_tokens:2, cache_creation_input_tokens:27542, cache_read_input_tokens:24062, output_tokens:4`. Story 04 Implementation notes (row built with `jq -cn`, stub logs argv to `$LITOPYS_STUB_LOG`).

## Acceptance criteria
- [ ] Worker probes the live shape once from a terminal - `claude -p --output-format json "say ok" | jq '{usage, modelUsage}'` - and records the exact field names seen in Implementation notes; the fixture stub's canned payloads mirror that shape (uncached `input_tokens` small, cache fields large, `output_tokens` non-zero).
- [ ] `tokens_in` = `usage.input_tokens + usage.cache_creation_input_tokens + usage.cache_read_input_tokens` (each `// 0`); `tokens_out` = `usage.output_tokens // 0`. When the top-level `usage` totals are 0 but a per-model usage object exists in the JSON, the same three-plus-one sum is taken over every model entry instead. `null` only when no usage object of either kind exists.
- [ ] A `claude` exit 0 whose JSON has `"is_error":true` produces a row with `hit:false`, `refs_matched:0` and `"error":"<first line of result or 'is_error'>"`, exactly like a non-zero exit.
- [ ] `tests/bench.test.sh` asserts, on the stub payloads: `tokens_in` equals the summed cache-inclusive figure (not the uncached slice), `tokens_out` equals `output_tokens`, one stub case with `is_error:true` yields `hit:false` + `error`, and the pre-existing assertions (5 rows, hit/refs fields, self-ignoring `.gitignore`, second run appends, stdin non-blocking, exact argv) still hold.
- [ ] Row keys and the one-line summary remain exactly C5; `append.test.sh` and `hooks.test.sh` are untouched and still green.

## Verification
`bash tests/bench.test.sh`

## Implementation notes
- Files: `bin/litopys`, `tests/fixtures/claude-stub.sh`, `tests/bench.test.sh`.
- **Live probe** (`claude -p --output-format json "say ok" | jq '{usage, modelUsage}'`, 2026-09-21, this machine) returned: `usage` = `input_tokens:2`, `cache_creation_input_tokens:50520`, `cache_read_input_tokens:0`, `output_tokens:4` (plus `output_tokens_details`, `server_tool_use`, `service_tier`, `cache_creation.{ephemeral_1h,ephemeral_5m}_input_tokens`, `inference_geo`, `iterations[]`, `speed`); `modelUsage` = a map keyed by model id (`claude-fable-5-1`) whose values are **camelCase**: `inputTokens`, `outputTokens`, `cacheReadInputTokens`, `cacheCreationInputTokens`, `webSearchRequests`, `costUSD`, `contextWindow`, `maxOutputTokens`, `thinkingTokens`, `canonicalModel`, `provider`, `costBasis`. Surprising: the per-model fallback is *not* the same key names as `usage`, so the jq sums both spellings (only one is ever present per object).
- Extraction lives in one `BENCH_USAGE_JQ` program above `cmd_bench` rather than inline: it is ~15 lines of jq and the inline single-quote form was unreadable. Preference order: top-level `usage` when its sums are non-zero → `modelUsage` summed over every entry → the all-zero `usage` → `null` only when neither object exists.
- `is_error` handling added as a `failed` flag beside `rc`; both the keyphrase scan and the refs scan gate on `failed`, so an `is_error:true` reply that happens to contain keyphrases still scores `hit:false` / `refs_matched:0`. Error text: first stderr line for a non-zero exit (unchanged), first line of `.result` for `is_error`, literal `is_error` when `.result` is empty.
- Stub: no room for a sixth question (bench demands exactly five sections and `tests/fixtures/golden-questions.md` is not in this story's files), so the `is_error` payload is selected by `LITOPYS_STUB_IS_ERROR=1` and the test exercises it in its own project dir after the argv assertions. Its `result` deliberately contains every question's keyphrases and refs, so the test proves scoring is suppressed rather than merely absent.
- Q2's stub payload now carries an all-zero top-level `usage` + a two-model `modelUsage`, which is what covers the fallback branch and the "every model entry" sum (2356 / 120).
- Row keys, summary line and `cost_usd` untouched; `append.test.sh` and `hooks.test.sh` still green.

## Findings
