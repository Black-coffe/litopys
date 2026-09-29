---
story: correction-evidence-03
spec: correction-evidence
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 2
blocked_by: [correction-evidence-02]
---

# `litopys corrections` lists the owner's corrections

## Goal
`bin/litopys corrections [--since YYYY-MM-DD] [--lexicon <file>]` is a read-only verb. It prints `<date> · <session8> · record · «quote»`
for each `## Corrections` line in `docs/chronicle/sessions/*.md`. With `--lexicon`, a file with one ERE per line, it also prints
`<date> · <session8> · lexicon · «line»` for each matching human line in the raw journals (`.litopys/raw/*.md`, `raw/done/*.md`,
`## user` blocks only). There is no model call and no write, and it exits 0 on no results.

## Requirements
> 3. команда `litopys corrections [--since] [--lexicon]` печатает «дата · сессия · «цитата»»

## Files
- bin/litopys
- tests/distill.test.sh
- README.md

## Non-goals
- litopys ships no lexicon of its own (owner's answer 2).
- No counting, ranking or filing logic. That is the consumer's job (the VULYK `/vulyk-evolve` follow-up).
- Do not read `## notice` blocks.

## Map slice
memory/map/litopys-plugin.md: `bin/litopys` verbs and usage.

## Acceptance criteria
- [ ] Two records, one with two Corrections lines and one with `- (none)`, give exactly two `record` lines, dated by each record's `date:`.
- [ ] `--since` drops the older record. A malformed date exits 2 with usage.
- [ ] `--lexicon` with `нет, не так` matches a human `## user` line of a raw journal, and does not match the same words inside a `## notice` block (neighbour form).
- [ ] With no records and no journals it prints nothing and exits 0. It writes nothing under the project.
- [ ] `litopys --help` and README list the verb in one line each.

## Verification
`bash tests/distill.test.sh`
`git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes

## Findings
