<!-- seat: review · model: unknown · round: 1 · head: 0d5c8c4 · pack: c9387cdbcdf8 · attempt: 2 · recorded: 2026-09-28T21:50:11Z · verdict: BLOCK -->
VERDICT: BLOCK

# lead-review: litopys-privacy-guard, round 1, attempt 2 (branch vulyk/litopys-privacy-guard @ 0d5c8c4)

Re-filed from attempt 1 with ask tags; same findings, no new investigation.

**Scope:** every file in `main...HEAD` is named in a story's `## Files`. `.gitignore` entered story 03's Files through the plan delta dated 2026-09-29. No Law 3 violation.

**What I ran instead of the suite:** throwaway git repos under %TEMP%, removed afterwards; the working tree is unchanged. Checks: `bin/litopys privacy` against a tracked nested `sub/.litopys/`; ripgrep 14.1.1 and this session's own Grep and Glob tools against a git-ignored `docs/chronicle/`; `json_str` under `BASH_COMPAT=51/43/42/32`; timing of the guard (0.2 s) and the hook (0.45 s), well inside the 10 s timeout.

## Critical

1. [regression] [ask 1] `agents/recall.md:14-28`, `docs/adr/010-private-by-default-managed-gitignore.md:44` - route `plan` - `/litopys:recall` must still find session records and monthly chronicle lines once Ask 1 git-ignores `docs/chronicle/*`, when it searches the way its instructions say (Grep over `docs/chronicle/`, or no path from the project root), checked against the real tool, and ADR-010's "Recall is unaffected: it reads the working tree" must be replaced with what was actually verified.

   Evidence (ripgrep 14.1.1, repo carrying the block): `rg ZEBRA .` and `rg ZEBRA docs/chronicle` both find only `golden-questions.md`; only an explicit `docs/chronicle/sessions` path finds the record; the month file `docs/chronicle/2026-09.md` is invisible from both. This Claude Code build's Grep tool gives the same result on `.../docs/chronicle`; Glob still lists all three files.

   Impact: recall's search step 2 (`docs/chronicle/`, "most likely to hold a direct answer") silently stops working in every default host. That is the Profile's client path. No test covers recall, and the release would ship the opposite claim as fact. Routing: nothing in the plan or the stories raised how the read path interacts with the new ignore rules.

## Major

2. [ask 2] `bin/litopys:203-207` - route `worker` - the printed untrack command must remove every file the tracked count includes, nested `*/.litopys/*` included, so that running it clears the warning.

   Evidence: a repo with tracked `sub/.litopys/raw/j.md` gets `1 litopys file(s) already tracked`; running the printed `git ls-files -ci --exclude-standard -z -- .litopys docs/chronicle | xargs -0 git rm --cached --quiet --` fails with `fatal: No pathspec was given` (rc 123), and the warning repeats every session forever. Routing: the story says the command covers "the litopys paths"; the worker put the nested pathspec into the count only.

## Minor

3. [ask 3] [regression] `bin/litopys:576-580` - route `plan` - `json_str` must produce valid JSON on every bash the plugin supports, or the supported bash floor must be recorded (Profile: "Linux/macOS sh must not break"; stock macOS ships bash 3.2). Under `BASH_COMPAT=42` and `32` the quoted replacements keep their literal double quotes, so a quote or tab comes out wrapped in stray quote characters that jq rejects; `BASH_COMPAT=43+` is correct (bash's documented compat42 rule). Regression from 0.2.1's `sed`, but only on odd `sid`/`--model` values.
4. [ask 3] `bin/litopys:851-856` - route `worker` - the rename-aside reclaim must never leave two holders: a third process can `mkdir` the lock inside the move-aside window, the move-back then nests the fresh lock inside the new one (`mv dir existing_dir`), and the `rm -rf` fallback can delete a live lock. Minor only because it needs three distill runs racing on one project dir; the Profile has one machine, one project dir at a time.
5. [ask 2] [ask 3] tests - route `worker` - each of these must have a test that fails when its guard is removed (today each could be reverted with the suite green): the raw-journal fail-closed `|| return 1` at `hooks/raw-journal.sh:71`; the move-back of a fresh lock (story 02 criterion; N7 covers only one stale reclaim); the `date -r` mtime fallback key in `distill next`; the no-jq banner with git present (the only no-jq case also removes git, so it exercises `nogitbin` only).
6. [ask 4] `docs/adr/010-private-by-default-managed-gitignore.md:14,49-50`, `CHANGELOG.md:15` - route `worker` - every factual claim in the ADR and in the CHANGELOG (the Release body) must hold or be dropped: "Every `.litopys/` writer goes through `ensure_scratch`" does not hold (`hooks/raw-journal.sh:71` keeps its own copy; `bin/litopys:1046` writes `.litopys/.finish-stderr` without the helper); "seven of the twelve writers" cannot be checked (the recon dir is empty) and a count on `main` finds about three or four.
7. [ask 3] `docs/specs/litopys-privacy-guard/recon/`, `plan.md` "Micro-defects in scope (recon D)" - route `plan` - the recon list that Ask 3 is judged against must exist on disk; the directory is empty, so no reviewer can map the numbered in-scope items to delivered fixes.
8. [ask 2] `bin/litopys:191-199` - route `plan` - the override check must catch any existing litopys file git would add, not only the synthetic `probe.md` names (an owner rule like `!docs/chronicle/sessions/2026-*` un-ignores real records while the probes stay ignored, so the guard stays quiet).
9. [ask 2] `hooks/session-start.sh:30-31` - route `plan` - in the no-jq path the model must also get "never git add -f these paths", per grill answer 3; today the fallback's `additionalContext` carries the bare privacy line.
10. [ask 1] `bin/litopys:1023` - route `worker` - the `kept local:` reason must not claim "docs/chronicle/ is git-ignored" unless that was checked; it is printed unconditionally (non-git root, a guard that `failed`, an owner override) and goes verbatim into the distiller's `**Commit:**` line.
11. [ask 1] `bin/litopys:136-137` - route `plan` - creating `.gitignore` must not follow a dangling symlink out of the project (`[ ! -f "$gi" ]` is true for one, and `printf > "$gi"` then creates the target; content fixed). Matters only if a Linux/macOS user opens an untrusted checkout; not reproduced on this Windows host.
12. [ask 2] `hooks/session-start.sh:14` - route `worker` - `plugin_root` must resolve when `$0` has no slash and `CLAUDE_PLUGIN_ROOT` is unset (`${0%/*}` of `session-start.sh` is the name itself, so the guard reports "did not run"; `dirname` handled it before). Near-zero impact: Claude Code always sets `CLAUDE_PLUGIN_ROOT`.
13. [ask 2] contract drift - route `worker` - the deltas must record these deviations or the code must match the contract: the block marker lacks the contract's "(managed)"; `privacy <arg>` exits 2 and prints the full usage against "exactly one line, always exit 0" (G10 asserts the 2); story 01's "exact `git rm -r --cached` command" became an `ls-files | xargs git rm --cached` pipeline (sound, it keeps `golden-questions.md` tracked, but no delta line).
14. [unanchored] `docs/adr/004-litopys-scratch-directory.md`, `docs/adr/007-pathspec-limited-commit-on-current-branch.md` - route `plan` - superseded ADRs must point at ADR-010; ADR-004 still states "No plugin code writes to a host's `.gitignore`" and ADR-007 still describes the default commit, and neither file is in story 03's Files.

## Observation outside this diff (no routing)
- `council/round-1/ROUND` has `seats=review` only, correct under `scripts/cycle.sh` `required_seats_for_tier` (ADR-013 D1); CLAUDE.md still says Tier 2 = `council-sonnet` + `lead-review`, so the constitution text is stale against the scripts.

## Checked and found sound
- Block detection and rewrite (CRLF, no final newline, dangling begin, hand-edited block, two blocks, empty file); the rewrite is idempotent.
- `--no-index` probe semantics and the golden-questions negation; index never written; opt-in round trip.
- `record_rel` sanitising; redactor refusal path; ISO sort key.
- `0.2.1` gone from all code, tests and manifests; `.gitkeep` removal leaves no empty tracked dirs.
- `systemMessage` / `additionalContext` shape; hook timing.
