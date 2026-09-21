---
story: litopys-phase-0-1-01
spec: litopys-phase-0-1
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: true
wave: 1
blocked_by: []
---

# Tracer: plugin manifest + `bin/litopys append`

## Goal
After this story the repo is a loadable Claude Code plugin named `litopys` (`claude --plugin-dir E:/Projects/litopys` accepts it, `claude plugin validate .` is green) and `bin/litopys append` writes one dated, idempotent line into the host project's `docs/chronicle/YYYY-MM.md` without any model. One bash test proves it.

## Requirements
> Репо `litopys` = плагин Claude Code: `.claude-plugin/plugin.json` (name `litopys`), `skills/`, `agents/`, `hooks/hooks.json`, `bin/`; грузится через `claude --plugin-dir E:/Projects/litopys` в VULYK и в самом litopys.
> `bin/litopys append --kind grill|brief|verdict|ship|handoff|note --ref <path> --note "<text>"` дописывает одну датированную строку в `docs/chronicle/YYYY-MM.md` проекта, в котором вызвана; идемпотентна по (ts, kind, ref); не требует модели.
> `scripts/redact.sh` на любом пути в git

## Files
- .claude-plugin/plugin.json
- bin/litopys
- .gitignore
- tests/append.test.sh

## Non-goals
- Do not create `hooks/hooks.json`, `skills/`, or `agents/` - those are stories 02 and 05; the manifest must validate without them.
- Do not implement `bench` (story 04); the dispatcher may list it in `help` as "not yet".
- Do not add a `--ts` flag or a backfill mode; `LITOPYS_NOW` env is the only clock override.
- Do not touch any file in E:/Projects/vulyk and do not edit any CLAUDE.md.
- No README, no CHANGELOG, no marketplace entry.

## Map slice
`docs/specs/litopys-phase-0-1/recon/vulyk-hooks.md` (journal.sh line format, redact.sh interface, fail-open convention); `memory/map/scripts.md` entries for `journal.sh` and `redact.sh`. Contracts C1, C2, C3 in plan.md.

## Acceptance criteria
- [ ] `.claude-plugin/plugin.json` has `name: litopys`, `version: 0.1.0`, a description; `claude plugin validate .` exits 0 (non-strict, see Findings; run it by hand, record the result in Implementation notes).
- [ ] `bash bin/litopys append --kind grill --ref docs/grill/x.md --note "hello"` run in a temp project creates `docs/chronicle/<YYYY-MM>.md` with a `# Chronicle <YYYY-MM>` header and exactly one line matching contract C3, and prints that line.
- [ ] Running the same command twice with the same `LITOPYS_NOW` leaves one line; a different `--ref` or `--kind` adds a second.
- [ ] A note containing a newline is written on one line; a note containing `ghp_` + 36 chars is masked when `scripts/redact.sh` exists in the project root, passthrough when it does not.
- [ ] `--kind bogus` or a missing `--ref` prints usage to stderr and exits 2 with no file written; every other path exits 0.
- [ ] Project root follows C1 (`CLAUDE_PROJECT_DIR`, then git toplevel, then `$PWD`).
- [ ] `.gitignore` contains `.litopys/`.
- [ ] Test runs under Git Bash on Windows with `mktemp -d`; no python, no jq needed by `append`.

## Verification
`bash tests/append.test.sh`

## Tracer
Layers this slice must cut through: plugin manifest recognised by the CLI (`--plugin-dir`), an executable under `bin/` reached by explicit `bash` path, a host-project file written outside the plugin dir, one test asserting the on-disk line. If `--plugin-dir` refuses the layout or `bin/` needs an extension on Windows, report it in Implementation notes - it changes stories 02, 04 and 05.

## Implementation notes
- Files: `.claude-plugin/plugin.json` (new), `bin/litopys` (new), `tests/append.test.sh` (new), `.gitignore` (+3 lines for `.litopys/`).
- **Tracer layers all cut.** `claude --plugin-dir E:/Projects/litopys -p "..."` from a foreign cwd loads the plugin and answers (Claude Code 2.1.278). `bin/litopys` is extension-less and is invoked as `bash "<root>/bin/litopys" <sub>` (C2) - no PATH exec, no `.sh`/`.cmd` needed on Windows. A host-project file outside the plugin dir is written correctly (test projects under `mktemp -d`). Stories 02/04/05 need no layout change.
- **`claude plugin validate . --strict` exits 1, and cannot exit 0 in this repo.** Non-strict exits 0 ("passed with warnings"); the single warning is `root: CLAUDE.md at the plugin root is not loaded as project context`, raised by the VULYK constitution at the repo root - a file this story's non-goals forbid touching. The manifest itself validates. See `## Findings`.
- Root resolution (C1) for the CLI is `CLAUDE_PROJECT_DIR` (must be a directory) -> `git rev-parse --show-toplevel` -> `$PWD`; the payload-`cwd` rung of C1 belongs to the hooks (story 05), not to `append`.
- Note pipeline order: `redact.sh` first, then newline/CR/tab collapse to spaces - that way redact's multi-line PEM pass still sees line breaks. `redact.sh` absent or failing = passthrough (its own documented "never eat the data" tradeoff), so a project without `scripts/` still records its note.
- Idempotence is `awk 'index($0, prefix) == 1'` on `- <ts> · <kind> · <ref> · ` - anchored at the line start, no regex, no jq, no python. A rerun prints the *stored* line, not the new note.
- Decision: an unknown **subcommand** also exits 2 with usage, alongside `--kind bogus` and a missing `--ref`. Acceptance criterion 5's "every other path exits 0" is read as every other *append* path; exiting 0 on a typo'd subcommand would hide the typo. `bench` exits 0 with "not yet - story 04".
- Mutation-checked, each guard separately, each one alone turning `bash tests/append.test.sh` red: idempotence check, redact.sh call, newline collapse, `# Chronicle` header, `--kind` whitelist, `--ref` required, git-toplevel fallback. Seven mutations, seven reds, restored clean between each.
- All four files are LF (`.gitattributes` `* text=auto eol=lf`); written through `newline='
'`/heredoc per the repo's CRLF gotcha.

## Findings
**Open question for the planner (does not block wave 2):** acceptance criterion 1 asks for `claude plugin validate . --strict` exit 0, but that is unreachable while `CLAUDE.md` sits at the repo root, and the story's own non-goals forbid editing it. The root `CLAUDE.md` is VULYK's constitution and cannot move; the CLI warns because a plugin root's `CLAUDE.md` is never loaded as plugin context (it is loaded as *project* context for this repo, which is what VULYK wants). Which does the project take?
1. Accept the warning and change the root `CLAUDE.md` `## Commands` "Build / typecheck" cell to `claude plugin validate .` (non-strict, exits 0) - a one-cell paperwork edit outside this story's file list, so a Queen/planner call, not mine.
2. Keep `--strict` and accept that the build/typecheck command is permanently red here.

Nothing else in the story is affected: the manifest itself is valid, and `--plugin-dir` loads the plugin.
