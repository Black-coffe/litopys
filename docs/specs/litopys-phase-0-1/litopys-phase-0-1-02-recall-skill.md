---
story: litopys-phase-0-1-02
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 2
blocked_by: [litopys-phase-0-1-01]
---

# `/litopys:recall` skill + sonnet agent

## Goal
After this story a user in any project with the plugin loaded can type `/litopys:recall <question>` and get back only an answer with file paths and commit references, produced by a sonnet subagent in a forked context that searched the project's chronicle, spec briefs, ADRs, grills, changelog, tags and git log. The main context never sees the search.

## Requirements
> Скилл `/litopys:recall <вопрос>` запускает сабагента (sonnet) в fork-контексте, который отвечает по `git log`, тегам, `CHANGELOG*`, `docs/specs/*/brief.md`, `docs/adr/`, `docs/grill/`, `docs/chronicle/`; в главный контекст возвращается только ответ со ссылками на файлы и коммиты.
> sonnet только

## Files
- skills/recall/SKILL.md
- agents/recall.md

## Non-goals
- No wiki, no index, no calendar, no distillation - phases 2-3.
- No second skill (no `/litopys:bench` skill; bench is a CLI in story 04).
- No vector search, no MCP, no `.mcp.json`.
- Do not widen the agent's tools beyond `Read, Grep, Glob, Bash`; do not let it write files.
- Do not edit `bin/litopys`, `plugin.json` or any hook.

## Map slice
Contract C6 in plan.md (frontmatter fields, search order, return shape). Grill brief `docs/grill/2026-09-21-project-memory-chronicle.md` D5 (navigation + grep, answer with links only) and Act 2 finding 3 (recall over git log / CHANGELOG / briefs / ADR / grills is the baseline).

## Acceptance criteria
- [ ] `skills/recall/SKILL.md` frontmatter has `name: recall`, `description` (one line, mentions "project history" and "answer with refs"), `context: fork`, `agent: recall`, `allowed-tools` per C6; body takes `$ARGUMENTS` as the question and fixes the search order: `docs/chronicle/`, `docs/specs/*/brief.md`, `docs/adr/`, `docs/grill/`, `CHANGELOG*`, `git tag`, `git log --oneline` (with `git show` / `git log -S` for drill-down).
- [ ] `agents/recall.md` frontmatter has `name: recall`, `model: sonnet`, `tools: Read, Grep, Glob, Bash`, a `description`; body demands the C6 return shape (`**Answer:**` ≤10 lines, `**Refs:**` list of repo-relative paths or 7-char shas with a reason each, `**Confidence:**`) and forbids returning search transcripts or file dumps.
- [ ] The skill body tells the agent to say "not found in project history" with the paths it searched when nothing matches, instead of guessing.
- [ ] `claude plugin validate .` exits 0 (non-strict; `--strict` is permanently red here, story 01 Findings).
- [ ] Manual check recorded in Implementation notes: in E:/Projects/vulyk with `--plugin-dir E:/Projects/litopys`, `/litopys:recall what changed in 0.15.0` returns the C6 shape with at least one path under `docs/` or a sha. If the `agent:` field rejects the plain name `recall`, try `litopys:recall` and record which one loaded.

## Verification
`claude plugin validate .`

## Implementation notes
- Files: `skills/recall/SKILL.md` (new, replaces `.gitkeep`), `agents/recall.md` (new, replaces `.gitkeep`).
- Frontmatter and search order copied verbatim from plan.md contract C6; `allowed-tools`/`tools` lists match exactly.
- `claude plugin validate .` (non-strict): passes with the same pre-existing warning as story 01 (root `CLAUDE.md` not loaded as plugin context) - exit 0.
- Manual check: `cd E:/Projects/vulyk && claude -p --plugin-dir E:/Projects/litopys "/litopys:recall what changed in 0.15.0"` returned the C6 shape (`**Answer:**` / `**Refs:**` / `**Confidence:**`) with multiple `docs/`/`CHANGELOG.md` paths and several 7-char shas. The plain `agent: recall` field loaded correctly - no need for the `litopys:recall` fallback.

## Findings
