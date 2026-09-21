---
story: litopys-phase-0-1-05
spec: litopys-phase-0-1
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 4
blocked_by: [litopys-phase-0-1-04]
---

# Raw journal hooks: Stop, UserPromptSubmit, SessionEnd flag, SessionStart banner

## Goal
After this story the plugin's `hooks/hooks.json` wires four events. `UserPromptSubmit` and `Stop` append the user's input and the assistant's last message, timestamped, to `.litopys/raw/<session_id>.md` in the host project (with cwd and git branch in its frontmatter). `SessionEnd` appends one closing line and returns well under a second. `SessionStart` injects the five-line C9 banner. Everything is bash + jq, fail-open, no model, nothing written to any CLAUDE.md.

## Requirements
> Хуки `Stop` и `UserPromptSubmit` пишут сырой журнал `.litopys/raw/<session_id>.md` (user_input, last_assistant_message, timestamp, cwd, git branch); `SessionEnd` только закрывает журнал флагом за ≤1 с; `SessionStart` подаёт ≤5 строк additionalContext (путь к хронике, число несведённых журналов, дата последней записи, имя скилла recall). `.litopys/` в gitignore, без ротации и без чистки.
> никаких вызовов `claude -p` или модели внутри хуков

## Files
- hooks/hooks.json
- hooks/raw-journal.sh
- hooks/session-start.sh
- tests/hooks.test.sh

## Non-goals
- No distillation, no consolidation, no lock file, no threshold banner asking the model to do anything - phase 2. The banner reports counts only.
- No PreCompact, SubagentStop or PostToolUse hooks.
- No rotation, size cap, cleanup, or redact on the raw journal (it never enters git).
- Do not read `transcript_path`; the journal is built only from payload fields.
- No python; if jq is missing, exit 0 silently (SessionStart: the static C9 fallback line).
- Do not edit `bin/litopys`, the manifest, or any host project's `.gitignore` or CLAUDE.md.

## Map slice
Contracts C1, C7, C8, C9 in plan.md. `recon/vulyk-hooks.md`: additionalContext JSON shape, `agent_id` skip on Stop, fail-open convention, no-timeout SessionEnd finding. Plan assumption on the `user_input` / `prompt` field name.

## Acceptance criteria
- [ ] `hooks/hooks.json` is byte-for-byte the C7 wiring (jq-valid, `${CLAUDE_PLUGIN_ROOT}` paths, no `timeout` on SessionEnd).
- [ ] `raw-journal.sh prompt` with `{"session_id":"s1","cwd":"<tmp>","user_input":"hi"}` creates `.litopys/raw/s1.md` with the C8 frontmatter (branch from `git -C <cwd> rev-parse --abbrev-ref HEAD` or `-`) and a `## user · <ts>` block; `.litopys/.gitignore` contains `*`. Reads `.user_input // .prompt`.
- [ ] `raw-journal.sh stop` with `last_assistant_message` appends a `## assistant · <ts>` block; a payload with non-empty `agent_id` writes nothing; a second session id gets its own file.
- [ ] `raw-journal.sh end` appends `## closed · <ts> · <reason>` and nothing else; when no journal exists it exits 0 without creating one; the test measures it below 1 s wall clock (`date +%s` before/after, difference 0 or 1 accepted, and the script contains exactly one write).
- [ ] `session-start.sh` prints the C9 JSON: chronicle file count and last entry date from `docs/chronicle/*.md` (`none` when absent), raw journal count from `.litopys/raw/*.md`, the recall line; output is exactly 5 `[litopys]` lines inside `additionalContext`, valid JSON (jq-checked in the test).
- [ ] Every script exits 0 on malformed or empty stdin, missing `cwd`, unwritable dir, and when `jq` is absent (test simulates with `PATH` stripped to a dir holding only bash coreutils shims, or skips with a note if that is impractical on the runner).
- [ ] Manual check in Implementation notes: one short session in E:/Projects/vulyk with `--plugin-dir E:/Projects/litopys` shows the banner and leaves a journal with user, assistant and closed blocks.

## Verification
`bash tests/hooks.test.sh`

## Implementation notes

## Findings
