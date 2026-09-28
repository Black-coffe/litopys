---
story: litopys-privacy-guard-01
spec: litopys-privacy-guard
status: done
returned: DONE
tier: 2
worker: worker-code
model: opus             # touches three contracts at once (banner, finish output, host .gitignore)
wave: 1
blocked_by: []
---

# Managed .gitignore guard, checked and announced every session

## Goal
A host project's `.gitignore` carries a litopys-managed block covering everything the plugin
generates; every session start re-ensures it, verifies it with git, warns loudly about files already
tracked, and tells both the owner and the model. `distill finish` no longer commits unless the owner
opts in with `LITOPYS_TRACK_CHRONICLE=1`.

## Requirements
> Всё, что litopys генерирует в проекте (.litopys/ и docs/chronicle/), само попадает в его .gitignore; для хроники есть явный выключатель LITOPYS_TRACK_CHRONICLE=1.
> Каждую сессию плагин это перепроверяет, дописывает недостающее и говорит об этом тебе и модели; файлы, уже лежащие в git, — громкое предупреждение с готовой командой.

## Files
- bin/litopys
- hooks/session-start.sh
- hooks/raw-journal.sh
- agents/distiller.md
- skills/distill/SKILL.md
- tests/privacy.test.sh
- tests/hooks.test.sh
- tests/distill.test.sh

## Non-goals
- No `git rm --cached`, no commit, no index write of any kind from the guard (grill answer 2).
- No write outside the managed block, no `.gitignore` in a non-git root, no global excludes.
- Do not move the chronicle out of `docs/chronicle/`; do not touch the chronicle line format.

## Map slice
memory/map/litopys-plugin.md - Entry points, C9 SessionStart banner, Hooks, Distill skill/agent pair.

## Acceptance criteria
- [ ] `bin/litopys privacy` in a git root with no block appends it to `<root>/.gitignore` (creating the
      file if absent, newline-safe) and prints a `[litopys] privacy: added ...` line; a second run
      changes nothing and prints the ok line; a block with different content is replaced, not duplicated.
- [ ] Block patterns: `.litopys/`, `docs/chronicle/*`, `!docs/chronicle/golden-questions.md`; with
      `LITOPYS_TRACK_CHRONICLE=1` only `.litopys/`.
- [ ] Tracked private files (`git ls-files -ci --exclude-standard` over the litopys paths) produce a
      `[litopys] PRIVACY:` line with their count and the exact `git rm -r --cached` command; the index
      is untouched.
- [ ] A protected probe path that `git check-ignore --no-index` does not report as ignored yields a
      `[litopys] PRIVACY:` override warning.
- [ ] A non-git root: no file written, the line says there is nothing to guard.
- [ ] SessionStart banner = 6 lines, line 6 the privacy line plus "never git add -f"; the same status
      goes out as top-level `systemMessage`; the no-jq path still runs the guard and emits valid JSON.
- [ ] `distill finish` without the opt-in prints `kept local: ...`, stages nothing, releases the lock,
      clears the manifest; with `LITOPYS_TRACK_CHRONICLE=1` the old commit contract holds.
- [ ] Every `.litopys/` writer goes through one `ensure_scratch` helper; `raw-journal.sh` does not write a
      journal when `.litopys/.gitignore` cannot be written (fails closed, still exit 0).
- [ ] distiller.md and SKILL.md name the `kept local` outcome and the `committed ` prefix correctly.

## Verification
for t in tests/*.test.sh; do bash "$t" || exit 1; done

## Implementation notes
- `bin/litopys`: `ensure_scratch` (every `.litopys/` writer), `privacy_block`/`ensure_private`/`guard_private`/`cmd_privacy` (C17). Block = last begin marker before the first end marker, markers matched by prefix; rewritten only when content differs; `awk` gets the block through ENVIRON, not `-v` (BSD awk rejects newlines in `-v`). `append`, `distill record`, `bench` call `guard_private` (stderr note only on change). `distill finish` returns `kept local: ...` unless `LITOPYS_TRACK_CHRONICLE=1`.
- `hooks/session-start.sh`: line 6 = privacy line (+ "never git add -f these paths" in a git repo), same line as top-level `systemMessage`; the no-jq path runs the guard via `$BASH` and `${0%/*}` (no `dirname`) and embeds the line raw.
- `hooks/raw-journal.sh`: self-ignore checked on every block, journal not written when it cannot be created.
- Tests: new `tests/privacy.test.sh` (G1-G10); `distill.test.sh` F0 default kept-local, F1-F13 under the opt-in; `hooks.test.sh` 6-line banner, git-repo guard case, no-jq guard. Surprise: the no-cwd banner cases ran from the repo root and the (correct) guard wrote this repo's .gitignore - they now run from `$T`; the G10 loop likewise skips non-directories.

## Findings
