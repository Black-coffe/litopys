---
story: litopys-privacy-guard-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. Всё, что litopys генерирует в проекте (.litopys/ и docs/chronicle/), само попадает в его .gitignore; для хроники есть явный выключатель LITOPYS_TRACK_CHRONICLE=1.
> 2. Каждую сессию плагин это перепроверяет, дописывает недостающее и говорит об этом тебе и модели; файлы, уже лежащие в git, — громкое предупреждение с готовой командой.

## Implementation notes
- Finding 1 (critical, recall): `agents/recall.md` and `skills/recall/SKILL.md` search stages 1-2 with `git grep --no-index --no-exclude-standard -n -i -e '<term>' -- docs/chronicle` (reads ignored files); the skill may run `Bash(git grep:*)`. `tests/privacy.test.sh` G11 runs that literal against an ignored chronicle and checks both files carry it. ADR-010's "Recall is unaffected" replaced with what was verified.
- Finding 2 (major, untrack): count, real-file check and printed command share one pathspec list (`.litopys '*/.litopys/*' docs/chronicle`); G5/G5b run the command exactly as printed and see the warning clear.
- Minors taken (plan delta 2026-09-29): 3 `json_str` per-character (P8 under BASH_COMPAT 32/42/51/52); 4 move-back only when the name is free, never rm (N7b, `find` shim); 5 tests for fail-closed journal, move-back, `date -r` key (N7c), no-jq-with-git banner; 6 ADR-010/CHANGELOG claims corrected, `.finish-stderr` fallback via `ensure_scratch`; 7 `recon/write-paths.md`; 8 `git ls-files --others` real-file check (G6b); 9 no-jq hint; 10 `kept local` checked with `git check-ignore` (F0b/F0c); 11 symlinked `.gitignore` never written (G12 - skips on Windows without symlink rights); 12 slash-less `$0`; 13 drift in plan deltas; 14 ADR-004/007 point at ADR-010.
- Surprise: the reviewer's example rule `!docs/chronicle/sessions/2026-*` does not un-ignore anything (git never re-includes under an excluded parent); G6b uses `!docs/chronicle/2026-*.md`, which does. Cygwin drops a CR passed to a child bash in argv under BASH_COMPAT - P8 feeds its input through a file.

## Findings
1. [regression] [ask 1] `agents/recall.md:14-28`, `docs/adr/010-private-by-default-managed-gitignore.md:44` - route `plan` - `/litopys:recall` must still find session records and monthly chronicle lines once Ask 1 git-ignores `docs/chronicle/*`, when it searches the way its instructions say (Grep over `docs/chronicle/`, or no path from the project root), checked against the real tool, and ADR-010's "Recall is unaffected: it reads the working tree" must be replaced with what was actually verified.
2. [ask 2] `bin/litopys:203-207` - route `worker` - the printed untrack command must remove every file the tracked count includes, nested `*/.litopys/*` included, so that running it clears the warning.

## Files
- bin/litopys
- hooks/session-start.sh
- hooks/raw-journal.sh
- agents/distiller.md
- skills/distill/SKILL.md
- tests/privacy.test.sh
- tests/hooks.test.sh
- tests/distill.test.sh
- agents/recall.md
- README.md
- CHANGELOG.md
- .claude-plugin/plugin.json
- .claude-plugin/marketplace.json
- tests/append.test.sh
- tests/bench.test.sh
- docs/wiki/session-record.md
- docs/wiki/chronicle-format.md
- docs/adr/010-private-by-default-managed-gitignore.md
- .claude-plugin/.gitkeep
- bin/.gitkeep
- hooks/.gitkeep
- skills/distill/.gitkeep
- examples/vulyk/.gitkeep
- tests/fixtures/.gitkeep
- .gitignore
- skills/recall/SKILL.md
- docs/adr/004-litopys-scratch-directory.md
- docs/adr/007-pathspec-limited-commit-on-current-branch.md
- docs/specs/litopys-privacy-guard/recon/write-paths.md

## Verification
`for t in tests/*.test.sh; do bash "$t" || exit 1; done`
