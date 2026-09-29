# ADR-011: Owner quotes in a record are verbatim, and harness text is a notice

- Status: accepted
- Date: 2026-09-30
- Spec: docs/specs/correction-evidence
- Amends: the phase-2 record contract (C11: the body's sections, checked by `distill record`); ADR-009
  (one journal = one record) is unchanged, but its body is now five sections, not four.

## Context
VULYK's editorial board studied vectorize-io/hindsight (VULYK `docs/specs/hindsight-memory/report.md`). The board found
two gaps in litopys.
- **Harness text is filed as the owner's.** The raw journal filed every prompt verbatim under `## user`, including subagent
  task-notifications, system reminders, other sessions' messages and pasted material. In VULYK's own journals, 61 of 110
  "user" blocks were subagent reports.
- **Records paraphrase the owner.** A record's decisions were a model's paraphrase, with no way to tell the owner's words
  from the distiller's.

VULYK's currency for owner intent is the verbatim quote (its ADR-014). A chronicle that paraphrases cannot feed it.
The owner asked, 2026-09-30: «Принимать в хронику только цитаты, которые дословно есть в журнале (C2).»

## Options
1. Keep paraphrased records and add a model-judged "fidelity" check. Rejected: a model call inside `distill record`
   breaks ADR-006's boundary, and it still cannot prove a quote.
2. Quote verbatim, and check each quote with a substring test against the journal's human text. Chosen.
   It is deterministic, costs nothing, and refuses the record the way a failed redactor does.

## Decision
- **The `prompt` hook splits harness text out.** It writes harness segments as `## notice · <ts> · <kind>` blocks
  (`task-notification`, `system-reminder`, `cross-session`, `pasted`), in prompt order. The human remainder goes first,
  as `## user`. Nothing is dropped. Code fences stay in `## user`.
- **The body has five sections:** `Decisions`, `Corrections`, `Problems`, `Brainstorm`, `Links`. A Decisions line may end
  with ` — «…»`. A Corrections line reads `- «…» — <what it corrected>`.
- **`distill record` checks every quote.** Each «…» must be a whitespace-normalised substring of the journal's `## user`
  text. `## notice` never counts. On a miss, the malformed Corrections line or the missing quote refuses the record:
  exit 2, nothing written, and the journal stays queued. Records already written are never re-validated.

## Consequences
- The chronicle can answer "what exactly did the owner say" with proof. The `litopys corrections` verb and VULYK's filed-rate
  count read `## Corrections`.
- A distiller that misquotes costs a retry instead of a wrong record.
- A journal written before this change still carries harness text in `## user`. For those journals the check is weaker,
  but it never becomes wrong.

## Invariants created
- Text inside «» in a record is the owner's words, found verbatim in that journal's `## user` blocks.
- A `## notice` block is never quoted as the owner.

## Revisit when
- The board's sunset rule is met. Once 20 `## Corrections` lines exist, the owner labels them. If precision is below 0.7,
  the section is removed.
- Owners routinely write in a way the substring test cannot follow (heavy quoting of quotes, `» — ` inside their own words).
