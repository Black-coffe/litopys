<!-- seat: review · model: unknown · round: 1 · head: 0d5c8c4 · pack: c9387cdbcdf8 · attempt: 1 · recorded: 2026-09-28T21:49:09Z -->
VERDICT: BLOCK

# lead-review: litopys-privacy-guard, round 1 (branch vulyk/litopys-privacy-guard @ 0d5c8c4)

**Scope:** every file in `main...HEAD` is named in a story's `## Files`. `.gitignore` entered story 03's Files through the plan delta dated 2026-09-29. No Law 3 violation.

**What I ran instead of the suite:** throwaway git repos under %TEMP%, removed afterwards. The working tree is unchanged.
- `bin/litopys privacy` against a tracked nested `sub/.litopys/`.
- ripgrep 14.1.1 and this session's own Grep and Glob tools against a git-ignored `docs/chronicle/`.
- `json_str` under `BASH_COMPAT=51/43/42/32`.
- Timing of the guard and the hook: 0.2 s and 0.45 s, well inside the 10 s timeout.

## Critical

1. **`agents/recall.md:14-28` and `docs/adr/010-private-by-default-managed-gitignore.md:44`, route `plan`.**
   - **Condition:** `/litopys:recall` must still find session records and monthly chronicle lines once `docs/chronicle/*` is git-ignored, when it searches the way its instructions tell it to (`Grep` over `docs/chronicle/`, or with no path from the project root). Check this against the real tool, and replace ADR-010's "Recall is unaffected: it reads the working tree" with what was actually verified.
   - **Evidence, ripgrep 14.1.1 in a repo carrying the block:** `rg ZEBRA .` finds only `golden-questions.md`. `rg ZEBRA docs/chronicle` also finds only `golden-questions.md`. Only an explicit `docs/chronicle/sessions` path finds the record. The month file `docs/chronicle/2026-09.md` is invisible from both `.` and `docs/chronicle`.
   - **Same result with this Claude Code build's Grep tool:** path `.../docs/chronicle` returned only `golden-questions.md`. `Glob` still lists all three files.
   - **Impact:** recall's search step 2 (`docs/chronicle/`, "most likely to hold a direct answer") silently stops working in every default host. That is the Profile's client path. No test covers recall, and the release would ship the opposite claim as fact.
   - **Routing:** nothing in the plan or the stories raised how the read path interacts with the new ignore rules.

## Major

2. **`bin/litopys:203-207`, route `worker`.**
   - **Condition:** the printed untrack command must remove every file the tracked count includes, nested `*/.litopys/*` included, so that running it clears the warning.
   - **Evidence:** a repo with tracked `sub/.litopys/raw/j.md` gets `1 litopys file(s) already tracked`. Running the printed `git ls-files -ci --exclude-standard -z -- .litopys docs/chronicle | xargs -0 git rm --cached --quiet --` fails with `fatal: No pathspec was given` (rc 123). The next session shows the same warning, and it repeats forever.
   - **Routing:** the story says the command must cover "the litopys paths", and the worker put the nested pathspec into the count only.

## Minor

3. **`bin/litopys:576-580`, route `plan`.**
   - **Condition:** `json_str` must produce valid JSON on every bash the plugin supports, or the supported bash floor must be recorded. Profile: "Linux/macOS sh must not break"; stock macOS ships bash 3.2.
   - **Evidence:** under `BASH_COMPAT=42` and `32`, the quoted replacements keep their literal double quotes, so a quote or tab in the input comes out wrapped in stray `"` characters, which jq rejects. `BASH_COMPAT=43+` is correct. This matches bash's documented compat42 rule: no quote removal in a double-quoted pattern-substitution replacement.
   - **Why minor:** it is a regression from 0.2.1's `sed`, which handled quote and backslash on any bash, but it only fires on odd `sid`/`--model` values.

4. **`bin/litopys:851-856`, route `worker`.**
   - **Condition:** the rename-aside reclaim must never leave two holders. Today a third process can `mkdir` the lock inside the move-aside window, and the move-back then nests the fresh lock inside the new one (`mv dir existing_dir`). The move-back fallback `rm -rf` can also delete a live lock.
   - **Why minor:** this only matters *if* three distill runs ever race on one project dir. The Profile has single machine, one project dir at a time, so today this is minor.

5. **Test gaps (test theater by omission), route `worker`.** Each of these must have a test that fails when its guard is removed. As things stand, each could be reverted and the suite would stay green:
   - `hooks/raw-journal.sh:71`: the fail-closed `|| return 1` when `.litopys/.gitignore` cannot be written. No test.
   - The lock move-back of a fresh lock (story 02 criterion). N7 only covers a single stale reclaim.
   - The `date -r` mtime fallback key in `distill next`. No journal without a valid `started` is ordered in any test.
   - The no-jq banner with git present. The only no-jq case also removes git, so it exercises `nogitbin` only.

6. **`docs/adr/010-private-by-default-managed-gitignore.md:14,49-50` and `CHANGELOG.md:15`, route `worker`.**
   - **Condition:** every factual claim in the ADR and CHANGELOG must hold, or be dropped.
   - **Claim 1:** "Every `.litopys/` writer goes through `ensure_scratch`", recorded as an invariant. It does not hold: `hooks/raw-journal.sh:71` keeps its own inline copy, and `bin/litopys:1046` writes `.litopys/.finish-stderr` without the helper.
   - **Claim 2:** "seven of the twelve `.litopys/` writers did not create" the self-ignore. This cannot be checked: `docs/specs/litopys-privacy-guard/recon/` is empty. A count on `main` finds about three or four skippers, not seven.

7. **`docs/specs/litopys-privacy-guard/recon/` and `plan.md` "Micro-defects in scope (recon D): 1 to 15", route `plan`.**
   - **Condition:** the recon list that Ask 3 is judged against must exist on disk.
   - **Why:** the directory is empty. No reviewer can check that each numbered in-scope item maps to a delivered fix. That makes Ask 3 unverifiable.

8. **`bin/litopys:191-199`, route `plan`.**
   - **Condition:** the override check must catch any existing litopys file that git would add, not only the synthetic `probe.md` names.
   - **Example:** an owner rule like `!docs/chronicle/sessions/2026-*` un-ignores real records, and the probes stay ignored, so the guard stays quiet. `git ls-files -o --exclude-standard` over the litopys paths would be the direct signal.

9. **`hooks/session-start.sh:30-31`, route `plan`.**
   - **Condition:** in the no-jq path the model must also get "never git add -f these paths", per grill answer 3 (the model gets the same line plus the git add -f ban).
   - **Today:** the fallback's `additionalContext` carries the bare privacy line.

10. **`bin/litopys:1023`, route `worker`.**
    - **Condition:** the `kept local:` reason must not claim "docs/chronicle/ is git-ignored" unless that was checked.
    - **Today:** it is printed unconditionally. That includes a non-git root, a guard that `failed` to write `.gitignore`, and an owner override. It goes verbatim into the distiller's `**Commit:**` line.

11. **`bin/litopys:136-137`, route `plan`.**
    - **Condition:** creating `.gitignore` must not follow a dangling symlink out of the project.
    - **Why:** `[ ! -f "$gi" ]` is true for a dangling link, and `printf > "$gi"` then creates the link target. The content is fixed. This matters *if* a Linux/macOS user opens an untrusted checkout; I did not reproduce it on this Windows host.

12. **`hooks/session-start.sh:14`, route `worker`.**
    - **Condition:** `plugin_root` must resolve when `$0` has no slash and `CLAUDE_PLUGIN_ROOT` is unset.
    - **Why:** `${0%/*}` of `session-start.sh` is the name itself, so the guard reports "did not run". `dirname` handled this case before.
    - **Real impact:** almost none, because Claude Code always sets `CLAUDE_PLUGIN_ROOT`.

13. **Contract drift, none of it recorded in `## Plan deltas`, route `worker`.**
    - The block marker is `# >>> litopys - private session data ...`, not the contract's `# >>> litopys (managed) ...`.
    - `privacy <arg>` exits 2 and prints the full usage. The contract says exactly one line and always exit 0. G10 asserts the 2.
    - Story 01 asks for "the exact `git rm -r --cached` command", but the delivered command is an `ls-files | xargs git rm --cached` pipeline. That deviation is sound, since it keeps `golden-questions.md` tracked, but it has no delta line.
    - The deltas must record these deviations, or the code must match the contract.

14. **`docs/adr/004-litopys-scratch-directory.md` and `docs/adr/007-pathspec-limited-commit-on-current-branch.md`, route `plan`.**
    - **Condition:** superseded ADRs must point at ADR-010.
    - **Today:** ADR-004 still states "No plugin code writes to a host's `.gitignore`" and ADR-007 still describes the default commit, with no "superseded/amended by ADR-010" line. Neither file is in story 03's Files.

## Observation outside this diff (no routing)
- `council/round-1/ROUND` has `seats=review` only. That is correct under `scripts/cycle.sh` `required_seats_for_tier` (ADR-013 D1). But CLAUDE.md still says Tier 2 = `council-sonnet` + `lead-review`. The constitution text is stale against the scripts.

## Checked and found sound
- Block detection and rewrite across these cases: CRLF, no final newline, dangling begin, hand-edited block, two blocks, empty file. The rewrite is idempotent.
- `--no-index` probe semantics, and the golden-questions negation.
- Index never written.
- Opt-in round trip.
- `record_rel` sanitising.
- Redactor refusal path.
- ISO sort key.
- Version literals: `0.2.1` is gone from all code, tests and manifests.
- `.gitkeep` removal leaves no empty tracked dirs.
- `systemMessage` / `additionalContext` shape.
- Hook timing.
