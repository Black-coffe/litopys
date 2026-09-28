# litopys privacy guard + 0.3.0 (plan)

**Tier:** 2 · **Spec slug:** `litopys-privacy-guard` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-004 (superseded in part by the new ADR-010 this spec writes), ADR-005, ADR-007 (commit path kept behind the opt-in)
**Depends on:** v0.2.1 on main (0ea23eb), VULYK 0.20.0 upgrade (07de29e)

## Goal
Everything litopys writes into a host project stays out of git by default, and the plugin proves it
every session. A managed block in the host's `<root>/.gitignore` covers `.litopys/` and
`docs/chronicle/*` (the owner-authored `golden-questions.md` stays trackable); `SessionStart` ensures
the block, verifies it with `git check-ignore`, lists tracked-but-private files with
`git ls-files -ci`, and says the result in one line to the owner (`systemMessage`) and to the model
(banner line 6, with "never git add -f"). `distill finish` keeps records local unless
`LITOPYS_TRACK_CHRONICLE=1`, which restores the ADR-007 commit and drops `docs/chronicle/*` from the
block. Then the recon's micro-defects, docs, and the 0.3.0 release.

## Assumptions
- Root for the block is the same C1 root the hooks use; `.litopys/` is written unanchored so a nested
  `sub/.litopys/` is covered too. Non-git roots get no `.gitignore` write (nothing to leak into; the
  next session after `git init` writes it) and the banner says so.
- The block is rewritten only when its content differs from the expected one (mode change or hand
  edit); an override that the block cannot fix (a later `!` rule, a nested `.gitignore`) is reported
  loudly, never silently patched outside the block.
- `git check-ignore --no-index` and `git ls-files -ci --exclude-standard` semantics verified on git
  2.55 in a scratch repo (2026-09-28): nested paths, non-existent probes and the golden-questions
  negation behave as the plan needs.
- `systemMessage` is the documented user-facing top-level hook field (code.claude.com hooks /
  agent-sdk docs); the `additionalContext` half was verified live with `claude -p` (the model read it).
  The interactive rendering of a SessionStart `systemMessage` was not observable from `-p`.
- The CLI writers (`append`, `distill record`, `bench`) also ensure the block, so a CLI run outside a
  session is covered; they stay silent on stdout (stderr note only when they changed the file).
- Asks 4 and 5, GitHub side (push main, tag v0.3.0, GitHub Release, About + topics) run at
  `/vulyk-ship` after GREEN, by the owner's grill answer 4. The council judges the branch side:
  version 0.3.0 in every literal, CHANGELOG 0.3.0 (the Release body), README, descriptions.
- Micro-defects in scope (recon D): 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, plus the stale
  `.gitkeep` files and `agents/recall.md`'s "no tool that can write files" claim. Out: 9 (scoping
  `Bash` in agent `tools:` - unverified syntax), 14 (map refresh is drone-docs' job at ship), the
  hooks-vs-CLI root divergence for sessions started in a subdirectory, and slimming the plugin
  payload (the whole repo ships; not a leak, Claude Code loads only plugin components).

## Stories

**Wave 1**
- `litopys-privacy-guard-01-gitignore-guard` — managed .gitignore block, per-session check + warning, banner line 6 + systemMessage, `distill finish` kept-local mode, `.litopys/` writers unified (opus)

**Wave 2**
- `litopys-privacy-guard-02-micro-fixes` — recon micro-defects: redactor failure, portable queue order, JSON escaping, path sanitising, lock reclaim, counts, test portability (sonnet)

**Wave 3**
- `litopys-privacy-guard-03-docs-release` — README, descriptions, wiki, ADR-010, CHANGELOG + version 0.3.0 everywhere, stale `.gitkeep` removed (sonnet)

## Contracts
- `bin/litopys privacy` prints exactly one line starting `[litopys] privacy:` (all good) or
  `[litopys] PRIVACY:` (something needs the owner), never `"` or `\`; always exit 0. Env:
  `CLAUDE_PROJECT_DIR`, `LITOPYS_TRACK_CHRONICLE`.
- Managed block: `# >>> litopys (managed) ... >>>` / patterns / `# <<< litopys <<<`.
- `distill finish` new outcome: `kept local: <reason>`; the distiller's `**Commit:**` accepts it.

## Integration gate
`for t in tests/*.test.sh; do bash "$t" || exit 1; done`

## Descoped

*(empty)*

## Plan deltas
- 2026-09-29, story 01 return (surprise note): the guard is correct in this repo too, so its first
  real session here will write the litopys block into this repo's own `.gitignore`. Decision: story
  03 ships that block as part of the release (`.gitignore` added to its `## Files`), so the owner's
  next session starts on the quiet ok line instead of an uncommitted change. Rejected: leaving it to
  the next session - a dirty tree right after a release.
- 2026-09-29, review round 1 (RED: critical 1, major 2): repair story 04 also takes the round's
  minors 3-14 at the Queen's call - they are defects of this same diff, cheaper to fix now than to
  ship. Story 04's `## Files` grows by `skills/recall/SKILL.md` (recall needs `Bash(git grep:*)`),
  `docs/adr/004-litopys-scratch-directory.md` and `docs/adr/007-pathspec-limited-commit-on-current-branch.md`
  (pointers to ADR-010), and `docs/specs/litopys-privacy-guard/recon/write-paths.md` (the recon list
  Ask 3 is judged against, written by the Queen from the scout's report). Rejected: a second spec for
  the minors.
- 2026-09-29, contract drift recorded (review minor 13): the block marker reads `# >>> litopys -
  private session data, kept out of git by the litopys plugin >>>` (matched by the `# >>> litopys`
  prefix), not "(managed)"; `privacy <arg>` is an argument error like every other verb (exit 2 +
  usage) - the one-line/exit-0 contract holds for the verb itself; the untrack command is the
  `git ls-files -ci ... | xargs -0 git rm --cached` pipeline over exactly the counted pathspecs, not
  `git rm -r --cached` - it keeps `golden-questions.md` tracked.

**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via grill, Andrei, 2026-09-28
**Branch:** vulyk/litopys-privacy-guard
**Checked:** <written by scripts/human-check.sh>
**Council:** RED round 1, 2026-09-28, at 5c2ba90, pack c9387cdbcdf8
**Shipped:** <written by scripts/ship-check.sh --record>
