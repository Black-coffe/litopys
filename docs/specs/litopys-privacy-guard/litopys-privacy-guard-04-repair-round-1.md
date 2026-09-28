---
story: litopys-privacy-guard-04
status: todo
returned:
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

## Verification
`for t in tests/*.test.sh; do bash "$t" || exit 1; done`
