---
story: litopys-phase-2-distill-03
spec: litopys-phase-2-distill
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 2
blocked_by: [litopys-phase-2-distill-01]
---

# `/litopys:distill` skill + sonnet `distiller` agent; recall reads `sessions/`

## Goal
`skills/distill/SKILL.md` (`context: fork`, `agent: distiller`) and `agents/distiller.md` (`model: sonnet`) implement C14: the agent calls `bin/litopys distill next`, reads each journal it is handed, writes a C11 body (title, Decisions, Problems, Brainstorm, Links) that says only what the journal supports, hands it to `bin/litopys distill record`, then calls `bin/litopys distill finish`, and returns the fixed five-field report. Both recall files gain `docs/chronicle/sessions/` as search stage 1 (frontmatter `topics` first, then bodies) so records are what recall cites.

## Requirements
> `agents/distiller` sonnet; запись сессии = плоский файл с frontmatter (date, topics, links, source: live|backfill)
> a `/litopys:distill` skill with `context: fork` and a sonnet `distiller` agent does the work; the SessionStart hook only counts journals awaiting distillation and, past a threshold, says so in the banner (line 4 repurposed, still five lines, D6/D7); a new `PreCompact` hook appends a `## compact · <ts>` marker to the raw journal so the distiller knows a compaction happened (D11)
> phase 2's distiller skips `## user` blocks whose first line starts with `/litopys:recall`
> a 100k session does not fit one line and recall needs a file to cite
> только sonnet для агента recall

## Files
- skills/distill/SKILL.md
- agents/distiller.md
- skills/recall/SKILL.md
- agents/recall.md

## Non-goals
- The agent never writes a record, a chronicle line, `.litopys/distill.jsonl`, or a commit itself - only the body file under `.litopys/`; `bin/litopys distill record|finish` do the rest. No `git` command in the agent body.
- No paths outside `docs/chronicle/` and `.litopys/`; never `memory/learnings/`, `memory/stats/`, `.claude/handoff/`, any `CLAUDE.md`.
- Do not invent a queue, a cap, a lock, or a skip rule in prose - `distill next` owns them (C12); the agent only ignores `/litopys:` user blocks *inside* a journal it was handed.
- Do not change recall's return shape (C6) or its stages 2-7; do not make recall read `.litopys/`.
- Do not make the skill run on SessionStart or accept a "background" mode. `$ARGUMENTS`, if present, is passed as `--max N` and nothing else.
- Do not touch `bin/litopys`, hooks, or tests.

## Map slice
`memory/map/litopys-plugin.md` - Recall skill/agent pair; `recon/plugin.md` Q3 (`SKILL.md:1-7, 19-27`, `agents/recall.md:1-6, 14-22`); `recon/host-and-journal.md` "Raw journal format" and "VULYK's own hooks" (the three paths to stay clear of); plan.md C11, C12 (the `next` stdout/stderr shape), C13, C14, C16.

## Acceptance criteria
- [ ] `skills/distill/SKILL.md` frontmatter exactly as C14 (`name: distill`, `description`, `context: fork`, `agent: distiller`, `allowed-tools: Read, Write, Grep, Glob, Bash`); `agents/distiller.md` frontmatter `name: distiller`, `description`, `model: sonnet`, `tools: Read, Write, Grep, Glob, Bash`.
- [ ] The agent body states the C14 procedure in order (next -> per journal: read, body, record, delete body -> finish -> report), the three CLI invocations verbatim in the `bash "${CLAUDE_PLUGIN_ROOT}/bin/litopys" ...` form, the C11 body shape with the four section names, `- (none)` for an empty section, `--topics`/`--links` as comma-separated repo-relative paths or sha7s only, and the exact return shape (Distilled / Skipped / Commit / Pending) - including the `locked` (exit 3) and nothing-pending outcomes.
- [ ] The agent body carries the C13 reading: one file = one session; `## closed` mid-file = exit + resume, not a boundary; `## compact` = context summarised at that point; `## user` blocks whose first line starts with `/litopys:` (and their paired `## assistant`) are ignored; no fact enters a section unless a journal block supports it; secret-shaped strings are never copied even though the record is redacted afterwards.
- [ ] `skills/recall/SKILL.md` and `agents/recall.md` carry an identical new stage 1 `docs/chronicle/sessions/` (grep frontmatter `topics:`/`links:` first, then bodies; cite the record path in `**Refs:**`), old stage 1 `docs/chronicle/` becomes stage 2, later stages renumbered; `model: sonnet` unchanged in `agents/recall.md`.
- [ ] `claude plugin validate .` passes (non-strict); every file LF.

- [ ] `agents/recall.md` still carries `model: sonnet` after the edit, and `agents/distiller.md` carries `model: sonnet` (Ask 10, D12).

## Verification
`claude plugin validate .`

## Implementation notes

## Findings
