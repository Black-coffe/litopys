---
story: litopys-phase-0-1-01
spec: litopys-phase-0-1
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: true
wave: 1
blocked_by: []
---

# Tracer: plugin manifest + `bin/litopys append`

## Goal
After this story the repo is a loadable Claude Code plugin named `litopys` (`claude --plugin-dir E:/Projects/litopys` accepts it, `claude plugin validate . --strict` is green) and `bin/litopys append` writes one dated, idempotent line into the host project's `docs/chronicle/YYYY-MM.md` without any model. One bash test proves it.

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
- [ ] `.claude-plugin/plugin.json` has `name: litopys`, `version: 0.1.0`, a description; `claude plugin validate . --strict` exits 0 (run it by hand, record the result in Implementation notes).
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

## Findings
