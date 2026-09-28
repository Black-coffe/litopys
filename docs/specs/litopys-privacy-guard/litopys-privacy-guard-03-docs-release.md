---
story: litopys-privacy-guard-03
spec: litopys-privacy-guard
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 3
blocked_by: [litopys-privacy-guard-02]
---

# Docs, descriptions and the 0.3.0 release paperwork

## Goal
Every user-facing text says what the plugin now does (private by default, guard every session,
distillation in a Sonnet subagent), the decision is on record as ADR-010, and the version is 0.3.0 in
every literal, with a CHANGELOG entry that doubles as the GitHub Release body.

## Requirements
> Минорный релиз 0.3.0 выкачен на GitHub: push main, тег v0.3.0, Release с заметками.
> Описание репо на GitHub (About, топики) и README чистые и точные.

## Files
- README.md
- CHANGELOG.md
- .claude-plugin/plugin.json
- .claude-plugin/marketplace.json
- bin/litopys
- hooks/session-start.sh
- tests/append.test.sh
- tests/bench.test.sh
- tests/hooks.test.sh
- docs/wiki/session-record.md
- docs/wiki/chronicle-format.md
- docs/adr/010-private-by-default-managed-gitignore.md
- .claude-plugin/.gitkeep
- bin/.gitkeep
- hooks/.gitkeep
- skills/distill/.gitkeep
- examples/vulyk/.gitkeep
- tests/fixtures/.gitkeep

## Non-goals
- No push, tag, GitHub Release or `gh repo edit` here - that is `/vulyk-ship` after GREEN.
- No behaviour change in code beyond the version literals.

## Map slice
memory/map/litopys-plugin.md - Purpose, Hooks.

## Acceptance criteria
- [ ] README: what and why in one paragraph, install, a privacy section (what is ignored, the opt-in,
      the per-session line, the tracked-files warning), CLI, env vars; no claim the code contradicts.
- [ ] plugin.json and marketplace.json descriptions accurate (hooks journal without a model call, a
      Sonnet subagent distills, private by default).
- [ ] ADR-010 records the reversal of ADR-004's "never write a host .gitignore" invariant and of
      ADR-007's default commit; the wiki notes no longer say records are committed by default.
- [ ] Version 0.3.0 in plugin.json, `bin/litopys` VERSION, the session-start fallback and every test
      literal; CHANGELOG `## 0.3.0` lists Security / Fixed / Changed.
- [ ] The six stale `.gitkeep` files are gone.

## Verification
for t in tests/*.test.sh; do bash "$t" || exit 1; done

## Implementation notes

## Findings
