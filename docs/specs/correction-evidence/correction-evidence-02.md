---
story: correction-evidence-02
spec: correction-evidence
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Chronicle quotes are the owner's exact words, or the record is refused

## Goal
The distiller body gains `## Corrections`, placed between Decisions and Problems, with lines shaped `- «verbatim» — what it corrected`. A `## Decisions` line may end with
` — «verbatim»`. `distill record` accepts the five-section body. It then refuses (exit 2, nothing written, journal still queued) any record with a quote
that is not a whitespace-normalised substring of the journal's `## user` text. `## notice` text never counts.
The distiller agent is told to quote only what it can find, and that `## notice` blocks are harness reports, never the owner.
ADR-011 records the shape change and the rule.

## Requirements
> 2. дистиллятор пишет «цитаты» в решениях и секцию `## Corrections`, а `distill record` отказывает, если цитаты нет дословно в ваших словах журнала

## Files
- bin/litopys
- agents/distiller.md
- tests/distill.test.sh
- docs/adr/011-verbatim-owner-quotes-in-records.md

## Non-goals
- Do not rewrite or re-validate records already on disk.
- No fuzzy matching and no model call in `distill record`. Matching is whitespace-normalised substring only.
- Do not add the `corrections` verb (story 03).

## Map slice
memory/map/litopys-plugin.md: `bin/litopys` `distill record`, and the distiller agent.

## Acceptance criteria
- [ ] A body with the five sections and a `## Corrections` quote found in a `## user` block is written.
- [ ] Original case: a Corrections quote that appears only in a `## notice` block is refused, exit 2, and the journal stays queued. Neighbour form: a Decisions quote that paraphrases the owner, with one word changed, is refused the same way.
- [ ] A quote that differs from the journal only in whitespace or line breaks is accepted.
- [ ] `- (none)` under Corrections is accepted. A four-section body (no Corrections) is refused with the section-order message naming the five sections.
- [ ] `agents/distiller.md` shows the five-section body, the quote rules, and the `## notice` rule. The rule "never paraphrase inside «»" is stated once.
- [ ] ADR-011 names ADR-009 and the phase-2 C11 contract as the records it amends, and records the board's sunset rule (20 labelled lines, precision below 0.7 → section removed).

## Verification
`bash tests/distill.test.sh`
`git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes

## Findings
