---
story: litopys-phase-0-1-06
spec: litopys-phase-0-1
status: todo
returned: NEEDS_CONTEXT
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 5
blocked_by: [litopys-phase-0-1-05]
---

# Report: raw journal vs `/export` on one real VULYK session

## Goal
After this story `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` exists and names, concretely, what the phase 1 raw journal loses compared to `/export` of the same ≥100k-token VULYK session. This is the evidence the grill's open assumption ("raw journal is enough for distillation without the jsonl") is decided on before phase 2 builds a distiller on top of it.

**Needs a human first.** The owner runs one real VULYK session past 100k tokens with `claude --plugin-dir E:/Projects/litopys`, then `/export` in that same session to a file, and gives the worker both paths: the journal `E:/Projects/vulyk/.litopys/raw/<session_id>.md` and the export file. The worker does not run the session.

## Inputs (provided by the Queen, 2026-09-21, on the owner's authority)
The human precondition is met. Both files exist; do not run any session yourself.
- Session id: `a10ea931-a24f-4942-aa20-743c4eeb9e4a`, project E:/Projects/vulyk, 2026-09-21, run under `claude --plugin-dir E:/Projects/litopys` (five `claude -p -r` turns with tool use, then one interactive resume for `/export` and `/exit`).
- Raw journal: `E:/Projects/vulyk/.litopys/raw/a10ea931-a24f-4942-aa20-743c4eeb9e4a.md`
- Export: `E:/Projects/vulyk/.litopys/export-a10ea931.md` (written by `/export` inside that session).
- Token count as Claude Code reported it (`--output-format json` usage per turn, input+cache_creation+cache_read): turn 1 129,774 · turn 2 160,046 · turn 3 570,413 (7 model calls, tool loop) · turn 4 218,625 · turn 5 128,088 (drop after turn 4 = auto-compaction candidate, check the export); output 302+1,079+2,198+8,601+736; total cost USD 2.38. Well past the 100k bar.
- Both files live under a gitignored `.litopys/`; quote at most a few lines per finding.

## Requirements
> Проверка на одной реальной сессии VULYK ≥100k токенов: сырой журнал сравнивается с `/export` той же сессии; отчёт `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` называет, что журнал теряет.

## Files
- docs/specs/litopys-phase-0-1/recon/raw-vs-export.md

## Non-goals
- Do not fix the hooks, change the journal format, or propose a new format in code - findings go in the report and become phase 2 input.
- Do not read the `~/.claude/projects/*.jsonl` transcript; the comparison is journal vs `/export` only.
- Do not paste large slices of either file into the report; quote at most a few lines per finding and cite by block header or turn number.
- Do not run a model over either file; the comparison is by reading and by `grep`/`wc`.

## Map slice
Contract C8 in plan.md (what the journal is supposed to contain). Grill brief Act 2 finding 1 ("как брейнштормили" is what a distiller drops first) and the assumption ledger line "Сырой журнал достаточен без jsonl - фаза 0, сравнить с /export".

## Acceptance criteria
- [ ] Report header records: session id, date, the session's token count as the owner reports it (≥100k), the two file paths and their sizes in bytes and lines, count of `## user` / `## assistant` blocks vs count of turns in the export.
- [ ] `## Losses` section: a numbered list where every item names one kind of content present in the export and absent or truncated in the journal (candidates to check, not a script: tool calls and their results, subagent output, intermediate assistant turns before the final one of a Stop, system reminders, compaction summaries, slash-command expansions, file diffs, anything cut by `last_assistant_message` semantics), each with one cited example (turn or block).
- [ ] `## Kept` section: what the journal preserves faithfully, with one example each.
- [ ] `## Verdict` section: one paragraph answering whether the journal alone can feed a distiller for "decisions, problems, brainstorm", and a list of at most three payload fields or hook events phase 2 would need to add. No design beyond that list.
- [ ] Every claim in Losses is checkable: a `grep` pattern or a block header the Queen can look up in the two files.

## Verification
`test -s docs/specs/litopys-phase-0-1/recon/raw-vs-export.md && grep -q '^## Losses' docs/specs/litopys-phase-0-1/recon/raw-vs-export.md && grep -q '^## Verdict' docs/specs/litopys-phase-0-1/recon/raw-vs-export.md`

## Implementation notes

## Findings
No ≥100k-token real session or `/export` file exists yet. The only raw journal on disk is `E:/Projects/vulyk/.litopys/raw/ac90b6ae-a213-4a9e-9330-f5d3c443b7c0.md` (339 bytes, 16 lines), a smoke test ("Say exactly: litopys hook smoke test"), not a real ≥100k-token VULYK session. No `/export` file was found anywhere under E:/Projects. Per the story's "Needs a human first" precondition, I cannot run the session myself. Please: run one real VULYK session past 100k tokens with `claude --plugin-dir E:/Projects/litopys`, `/export` it to a file, and give me both paths (the journal under `E:/Projects/vulyk/.litopys/raw/<session_id>.md` and the export file) plus the session's reported token count.

Re-checked 2026-09-21 after story 05 landed: still unmet. `E:/Projects/vulyk/.litopys/raw/` holds exactly one file, the same 339-byte / 16-line smoke test (`ac90b6ae-a213-4a9e-9330-f5d3c443b7c0.md`, one `## user` + one `## assistant` block); `find` over E:/Projects for any `*/.litopys/raw/*` returns only that file, and no `/export` output exists under E:/Projects, `C:/Users/Andrei` (depth 2), Downloads or Desktop. Without both files the report's header, Losses and Kept criteria cannot be produced from evidence, and inventing them would be the opposite of what this story is for.
