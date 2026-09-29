---
story: correction-evidence-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 2. дистиллятор пишет «цитаты» в решениях и секцию `## Corrections`, а `distill record` отказывает, если цитаты нет дословно в ваших словах журнала
> 3. команда `litopys corrections [--since] [--lexicon]` печатает «дата · сессия · «цитата»»

## Findings
1. bin/litopys:751 [ask 2] distill record must refuse a Decisions line whose «…» is not in the journal's ## user text wherever the «…» sits on the line; today only a line ending exactly in `»` is checked, so `- revert — «я этого никогда не говорил».` (trailing period) is written as a record with a fabricated owner quote, against ADR-011's invariant - repro: in a project whose journal lacks those words, `bash bin/litopys distill record --journal <journal> --body <body with that Decisions line>` exits 0 and prints the record path
2. bin/litopys:1253 [ask 3] `litopys corrections --lexicon` must match case-insensitively for Cyrillic text in the default Git Bash environment (LANG unset), as the plan's C3 states; today `grep -Ei` folds ASCII only, so the lowercase lexicon line `опять` / `не так` misses the owner's `Опять не то. Не так, переделай.`, and only `LC_ALL=C.UTF-8` finds it - repro: journal a prompt `Опять не то. Не так, переделай.` via hooks/raw-journal.sh, then `printf 'опять\nне так\n' > lex.txt; bash bin/litopys corrections --lexicon lex.txt` prints no lexicon line (the test at tests/distill.test.sh:797-801 uses all-lowercase text and cannot fail on this)

## Files
- hooks/raw-journal.sh
- tests/hooks.test.sh
- bin/litopys
- agents/distiller.md
- tests/distill.test.sh
- tests/fixtures/distill-body.md
- docs/adr/011-verbatim-owner-quotes-in-records.md
- README.md

## Verification
`bash tests/hooks.test.sh`
`git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/distill.test.sh`

## Implementation notes
- Finding 1: `distill_record` reads a Decisions quote from the first « to the last », wherever it sits on the line. A line with « and no » is refused. New cases: the original (`— «…».`, trailing period), a neighbour (a quote mid-line), and an unclosed «. HEAD's CLI writes the original as a record. `distiller.md` and ADR-011 now say "one «…» anywhere on the line".
- Finding 2: `cmd_corrections` runs the lexicon grep under the first UTF-8 locale that `locale -a` lists (C.UTF-8 / C.utf8 / en_US.UTF-8), falling back to C.UTF-8. New cases run with LANG/LC_* unset: lowercase «опять» finds «Опять…» (the original), and uppercase «НЕ ТАК» finds «нет, не так…» (the neighbour).
- The four minors are left for the next brief. Repair scope is the RED findings only.
