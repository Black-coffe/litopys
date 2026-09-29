# Correction evidence: notice blocks, verbatim quotes, `litopys corrections` (plan)

**Tier:** 2 · **Spec slug:** `correction-evidence` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-006 (no model calls in hooks), ADR-009 (one journal = one record), ADR-005 (redaction delegated to the host); the phase-2 record contract (C11: body sections checked by `distill record`)
**Depends on:** v0.3.0 on main (72c82ee); VULYK study `docs/specs/hindsight-memory/report.md` (C1, C2, C3)

## Goal
The chronicle carries the owner's real words, and only theirs.

The raw journal stops filing harness text as `## user`. Today in VULYK's journals 61 of 110 "user" blocks are subagent reports.
Every «quote» the distiller writes, in a `## Decisions` line or in a new `## Corrections` section, must appear
word for word in the journal's human text, or `distill record` refuses the record.

A read-only `litopys corrections` prints those quotes. With a lexicon file from the consumer, it also prints lexicon hits over the raw human
text at no model cost. VULYK's `/vulyk-evolve` counter is a VULYK change made after this ships.

## Assumptions
- **C1, how a prompt is split.** The `prompt` hook cuts `<task-notification>`, `<system-reminder>`, `<cross-session-message>` and `<pasted_content>` segments
  out of the prompt. The cut list mirrors VULYK's `defect-intake.sh` BLOCKS; code fences stay, because they are the owner's content.
  The human remainder, if any is left, is written first as `## user · <ts>`. Then each cut segment is written verbatim as its own
  `## notice · <ts> · <kind>` block, with `kind` one of `task-notification`, `system-reminder`, `cross-session`, `pasted`.
  Nothing is dropped. Human text first keeps the queue's first-user skip rule (`journal_scan`) working. The cut runs in jq,
  so the hook stays model-free and gains no new dependency.
- **C2, where quotes are validated.** A quote is checked against the whitespace-normalised concatenation of the journal's `## user` blocks, never
  `## notice`. In `## Corrections`, a line is `- «<verbatim>» — <what it corrected>`, and the quote ends at the line's last `» — `.
  In `## Decisions`, a line may end with ` — «<verbatim>»`, and the quote is the last such group on the line. A quote that is not found
  makes the record fail (exit 2, nothing written, journal stays queued), the same as a failing redactor. The distiller is
  told to omit a quote it cannot find, never to paraphrase one.
- **C2, the record shape.** Sections go `Decisions`, `Corrections`, `Problems`, `Brainstorm`, `Links`. Records already written are
  never rewritten or re-validated. A new ADR-011 records the shape change and the verbatim rule.
- **Sunset (board, Opus).** After 20 `## Corrections` lines exist, the owner labels them. At a precision below 0.7 the section is removed.
  This is recorded in ADR-011, and nothing is built for it now.
- **C3, the `corrections` command.** It reads records under `docs/chronicle/sessions/` and prints
  `<date> · <session8> · record · «quote»` per `## Corrections` line, skipping `- (none)`. `--since YYYY-MM-DD` filters by record date.
  `--lexicon <file>` holds one ERE per line and adds `<date> · <session8> · lexicon · «line»` for each human line of `.litopys/raw/*.md`
  and `.litopys/raw/done/*.md` that matches, case-insensitive. It exits 0 when it finds nothing. litopys ships no lexicon of its own
  (owner's answer 2).
- The version becomes 0.4.0 (record format change), in `.claude-plugin/plugin.json` and CHANGELOG at `/vulyk-ship`.

## Stories

**Wave 1**
- `correction-evidence-01` — `hooks/raw-journal.sh`: human text as `## user`, harness segments as `## notice · <kind>`; fixtures in `tests/hooks.test.sh`
- `correction-evidence-02` — `distill record` validates «quotes» against `## user` text, accepts `## Corrections`; `agents/distiller.md` body + notice rule; ADR-011; `tests/distill.test.sh`

**Wave 2** (shares `bin/litopys` and `tests/distill.test.sh` with 02)
- `correction-evidence-03` — `litopys corrections [--since] [--lexicon]`, a read-only verb; README usage line; tests in `tests/distill.test.sh`

## Contracts
- The record body adds a `## Corrections` section between Decisions and Problems. Its line shape is `- «<verbatim>» — <what>`. Story 03 reads it exactly as story 02 writes it.

## Integration gate
`for t in tests/*.test.sh; do bash "$t" || exit 1; done` · `git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Descoped
- The `/vulyk-evolve` counter is VULYK work after this ships. The owner's request names it as a follow-up: «Добавить команду litopys corrections, а после неё — счётчик в /vulyk-evolve (C3).» The confirmed question (answer 3) placed it in VULYK.

## Plan deltas

**Approved:** Andrei, 2026-09-30 («Да»)
**Briefed:**
**Branch:**
**Checked:**
**Council:**
**Shipped:**
