# ADR-009: One raw journal file is one session record, regardless of mid-file `## closed`/`## compact` markers

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-2-distill

## Context
From `plan.md` C8/C13 (amended: 02 writes, 01 reads):
> Parser rule (`distill record`, and the distiller's prompt): **one journal file = one session record**, whatever the number of `## closed` and `## compact` blocks. `## closed` followed by more blocks means a process exit and a resume; the record spans all blocks; frontmatter `ended` = ts of the last `## closed` when it is the file's last block, else `-`. `## compact` means the assistant's context was summarised at that point - the distiller treats blocks after it as the same session with reduced memory of the earlier ones. Neither marker splits or truncates anything.

## Options
none recorded - the delta states the chosen shape only.

## Decision
A raw journal file's entire content, from first line to last, is distilled into exactly one `docs/chronicle/sessions/<date>-<sid8>.md` record, no matter how many `## closed` or `## compact` blocks it contains. `## closed` mid-file signals a process exit followed by a resume within the same file; `## compact` signals a context summarisation point that the distiller reads as reduced memory of earlier blocks, not a session boundary. `ended` in the record's frontmatter is the last `## closed` timestamp only when it is the file's final block; otherwise `-`.

## Consequences
The distiller and `distill record` never need to split a journal or produce multiple records from one file, keeping C11's one-record-per-journal invariant simple and testable. The cost: a long-lived, many-times-resumed-and-compacted journal still becomes a single record, so very long or eventful sessions must be captured in one Decisions/Problems/Brainstorm/Links body rather than several - fidelity depends on the distiller reading the whole file rather than skimming to the last block.

## Invariants created
No code path in `distill record`, `distill next`, or the `distiller` agent may produce more than one chronicle session record from a single raw journal file. `ended` is only ever taken from a final-position `## closed` block.

## Revisit when
A journal grows long/eventful enough that a single record loses useful fidelity (e.g., a session resumed across days), prompting a design for per-block or per-resume sub-records.
