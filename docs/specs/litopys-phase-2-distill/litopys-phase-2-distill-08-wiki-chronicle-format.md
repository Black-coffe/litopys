---
story: litopys-phase-2-distill-08
spec: litopys-phase-2-distill
status: todo
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 5
blocked_by: [litopys-phase-2-distill-06]
---

# `docs/wiki/chronicle-format.md` describes v0.2.0 (C3 amended, `## compact`, plugin redactor)

## Goal
The format reference stops contradicting the shipped code (review round 1, major 5). C3 lists seven kinds including `session`; `<ref>` is documented as normalised (`\n`/`\r`/`\t` -> space, ` · ` -> ` - `) and redacted through the same filter as `<note>`, so the two "never redacted / never masked" sentences are gone; redaction is described as host `scripts/redact.sh` first, then the plugin's `${CLAUDE_PLUGIN_ROOT}/scripts/redact.sh`, then passthrough (C16); the C8 block list gains `## compact · <ts> · <trigger>` (`PreCompact`, appended only to an existing journal, own `journal_compact()`), and the C13 reading is stated once: one journal file = one session, `## closed` mid-file = exit + resume, `## compact` = context summarised at that point.

## Requirements
> запись сессии = плоский файл с frontmatter (date, topics, links, source: live|backfill)
> PreCompact-блок
> the plugin ships `scripts/redact.sh`, VULYK's file copied verbatim with the caller names in the header changed; `append` and the distiller use the host's `scripts/redact.sh` when present, else the plugin's; `--ref` is collapsed to one line and passed through the same redactor as `--note`; a distilled record is redacted before it is written
> After `## closed`, a further prompt re-opens the same journal file and appends past the close marker ... the phase-2 consolidator will need a rule for journals with a close marker in the middle.
> Review round 1 major 5: `docs/wiki/chronicle-format.md` must state the C3 amended rules (seven kinds, ref normalisation + redaction, host-then-plugin redactor) and the `## compact` block.

## Files
- docs/wiki/chronicle-format.md

## Non-goals
- Do not document the C11 session record, the C12 queue, or `distill.jsonl` in this file beyond one "see plan.md C11-C14" pointer - this wiki page is the C3 line and the C8 journal, not the distiller.
- Do not restate the resume-parking rule of story 07 or the manifest; they are `next`/`finish` behaviour, not a file format.
- Do not touch `memory/map/` (librarian, after merge), `CHANGELOG.md`, or any code or test.
- Do not change the frontmatter keys except `last-verified` and, if useful, `related`.

## Map slice
`docs/wiki/chronicle-format.md` whole (the file being amended); story 01 `## Implementation notes` (`redactor()`, ref normalise+redact, `session` kind) and story 02 `## Implementation notes` (`journal_compact()`, `.compaction_trigger // .trigger // "-"`); plan.md C3 (amended), C8/C13, C16; `council/round-1/review.md` finding 5 (the four contradictions, with `bin/litopys` line refs).

## Acceptance criteria
- [ ] The C3 kind list reads `grill brief verdict ship handoff note session`; the sentences "`<ref>` ... never redacted" and "`<ref>` itself is never masked by `redact.sh`" are replaced by the normalisation + redaction rule and the "empty after normalisation -> exit 2" rule; idempotence is stated on the normalised ref.
- [ ] Redaction paragraph names the C16 resolution order (host `<project-root>/scripts/redact.sh` -> `${CLAUDE_PLUGIN_ROOT}/scripts/redact.sh` -> `<bin dir>/../scripts/redact.sh` -> passthrough), the best-effort fallback, and that hooks never redact.
- [ ] C8 block list has a `## compact · <ts> · <manual|auto|->` bullet with the `PreCompact` event, the existing-journal guard and its own timeout (10 s) - distinct from `## closed`, which keeps its "no timeout, one append" sentence unchanged.
- [ ] One short C13 paragraph: one file = one session; a `## closed` followed by more blocks is a process exit + resume, not a boundary; `## compact` marks a context summary; neither splits or truncates.
- [ ] Header source line and `last-verified` name v0.2.0 / spec `litopys-phase-2-distill`; the file stays LF.

## Verification
`grep -q 'note session' docs/wiki/chronicle-format.md && grep -q '## compact' docs/wiki/chronicle-format.md && ! grep -q 'never redacted' docs/wiki/chronicle-format.md`

## Implementation notes
- `docs/wiki/chronicle-format.md`: C3 kind list gained `session`; the "never redacted"/"never masked" sentences replaced by the normalise-then-C16-redact rule and the exit-2-on-empty rule (idempotence keyed to the normalised ref).
- Added a C16 paragraph (host `<root>/scripts/redact.sh` -> plugin `${CLAUDE_PLUGIN_ROOT}/scripts/redact.sh` -> `<bin dir>/../scripts/redact.sh` -> `cat`), best-effort fallback, hooks never redact.
- C8 block list gained a `## compact · <ts> · <manual|auto|->` bullet (PreCompact, existing-journal guard, own 10s timeout, `.compaction_trigger // .trigger // "-"`), distinct from `## closed`'s unchanged no-timeout sentence.
- Added one C13 paragraph: one file = one session; `## closed` + more blocks = exit/resume, not a boundary; `## compact` = context summary; neither splits/truncates.
- Header source line names v0.2.0/`litopys-phase-2-distill`; added a one-line C11-C14 pointer per the non-goal; `related` frontmatter gained the plan.md pointer. File stays LF, no code/test touched.

## Findings
