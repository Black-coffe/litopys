---
story: litopys-phase-0-1-06
spec: litopys-phase-0-1
status: todo
returned:
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
