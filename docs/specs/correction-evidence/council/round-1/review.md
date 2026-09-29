<!-- seat: review · model: claude-opus-5-5 · round: 1 · head: 01b623d · pack: 0bf0639b2803 · attempt: 1 · recorded: 2026-09-29T21:40:52Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-opus-5-5

## Critical
None.
## Major
1. bin/litopys:751 [ask 2] distill record must refuse a Decisions line whose «…» is not in the journal's ## user text wherever the «…» sits on the line; today only a line ending exactly in `»` is checked, so `- revert — «я этого никогда не говорил».` (trailing period) is written as a record with a fabricated owner quote, against ADR-011's invariant - repro: in a project whose journal lacks those words, `bash bin/litopys distill record --journal <journal> --body <body with that Decisions line>` exits 0 and prints the record path
2. bin/litopys:1253 [ask 3] `litopys corrections --lexicon` must match case-insensitively for Cyrillic text in the default Git Bash environment (LANG unset), as the plan's C3 states; today `grep -Ei` folds ASCII only, so the lowercase lexicon line `опять` / `не так` misses the owner's `Опять не то. Не так, переделай.`, and only `LC_ALL=C.UTF-8` finds it - repro: journal a prompt `Опять не то. Не так, переделай.` via hooks/raw-journal.sh, then `printf 'опять\nне так\n' > lex.txt; bash bin/litopys corrections --lexicon lex.txt` prints no lexicon line (the test at tests/distill.test.sh:797-801 uses all-lowercase text and cannot fail on this)
## Minor
- agents/distiller.md:3 the frontmatter description still says "a four-section body" while the body now has five sections
- hooks/raw-journal.sh:101 the cut pattern is case-sensitive, while VULYK's defect-intake BLOCKS it mirrors use re.I
- bin/litopys:696 an owner line starting with `## ` inside a prompt ends the ## user text collection, so a later quote from that prompt is refused (fails closed, costs a retry)
- docs/adr/011-verbatim-owner-quotes-in-records.md:45 the invariant "Text inside «» in a record is the owner's words" is wider than the check, which ignores «» in Problems, Brainstorm and Links
