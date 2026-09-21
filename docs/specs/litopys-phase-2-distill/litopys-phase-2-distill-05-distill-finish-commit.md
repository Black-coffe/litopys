---
story: litopys-phase-2-distill-05
spec: litopys-phase-2-distill
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 3
blocked_by: [litopys-phase-2-distill-04]
---

# `bin/litopys distill finish` - pathspec commit on the current branch, lock release

## Goal
`bash bin/litopys distill finish` closes a distillation run: it stages and commits **only** `docs/chronicle/` on whatever branch the host is on (`git add -- docs/chronicle && git commit -m "chore(chronicle): distill <n> session(s) [litopys]" -- docs/chronicle`), leaving every other staged or unstaged change exactly as it found it; when the repo has no clean way to commit it leaves the files in the working tree and prints why; in every case it removes `.litopys/distill.lock`. Output is one stdout line - `committed <sha7>` or `uncommitted: <reason>` - and exit 0 (finish is never a gate; a failed commit is reported, not fatal).

## Requirements
> redact; коммит мимо рабочих веток; lock + cap N очереди
> the distiller writes the record and the chronicle line into the working tree and commits *only those paths* on the current branch (`git commit -- docs/chronicle/`), never touching staged or unstaged work outside `docs/chronicle/`; if the repo has no clean way to commit (detached HEAD, merge in progress, rebase) it leaves the files uncommitted and says so

## Files
- bin/litopys
- tests/distill.test.sh

## Non-goals
- No branch creation, checkout, stash, worktree, push, or tag. Never `git add -A`, `git add .`, or `git commit -a`. Never `--no-verify`.
- Do not touch the index outside `docs/chronicle/`: a host file staged before `finish` must still be staged, unchanged, afterwards; an unstaged host edit must still be unstaged.
- Do not set or override `user.name`/`user.email`; a missing identity is an `uncommitted: <git's first stderr line>` outcome.
- Do not commit when there is nothing under `docs/chronicle/` to commit - `uncommitted: nothing to commit`, still release the lock.
- Do not change `next` or `record` (stories 04, 01) except to share the lock path constant; do not touch `bench`, hooks, agents, skills.
- `<n>` in the message is the count of `session` lines added under `docs/chronicle/` in this diff (`git diff --cached -- docs/chronicle` on the staged set); do not read `distill.jsonl` for it.

## Map slice
`memory/map/litopys-plugin.md` - Entry points (CLI), C1; `recon/plugin.md` Q2 (`project_root()`), Q4 (test pattern); `recon/host-and-journal.md` "VULYK's own hooks" (the host repo's other writers); plan.md `## Assumptions` (first bullet - the refusal list), C12 (lock), C14 (`finish` is step 3 of the agent).

## Acceptance criteria
- [ ] Throwaway repo (`git init`, identity set locally, one prior commit) with a record + chronicle line written by `distill record`, plus a staged host file `a.txt` and an unstaged edit to `b.txt`: `finish` prints `committed <sha7>`; `git show --stat HEAD` lists only paths under `docs/chronicle/`; `a.txt` is still staged, `b.txt` still modified and unstaged; `.litopys/distill.lock` is gone; branch unchanged.
- [ ] Detached HEAD (`git checkout --detach`): `uncommitted: detached HEAD`, files remain untracked/modified in the working tree, lock removed. Likewise with a `.git/MERGE_HEAD` file present (`uncommitted: merge in progress`), a `.git/rebase-merge/` dir (`uncommitted: rebase in progress`), and a `.git/CHERRY_PICK_HEAD` file.
- [ ] Not a git repo: `uncommitted: not a git repository`, lock removed, exit 0.
- [ ] Nothing new under `docs/chronicle/`: `uncommitted: nothing to commit`, no commit created, lock removed.
- [ ] Repo without any git identity (`HOME` and `GIT_CONFIG_GLOBAL` pointed at an empty dir, no local `user.*`): `uncommitted: <first stderr line of git commit>`, no commit, lock removed.
- [ ] A host `pre-commit` hook that exits 1 (a two-line script in `.git/hooks/`): `uncommitted: ...`, no commit; a hook that exits 0 is run, not bypassed.
- [ ] Commit message is exactly `chore(chronicle): distill <n> session(s) [litopys]` with `<n>` = the number of new `· session ·` lines in the staged chronicle diff (2 in a two-record run).
- [ ] `finish` with no lock present still works (idempotent) and prints normally.
- [ ] Every file LF; `bash -n bin/litopys` clean; no model call.

## Verification
`bash tests/distill.test.sh`

## Implementation notes
- `bin/litopys`: added `distill finish` (`distill_finish` + helpers `git_block_reason`, `git_error_line`), the `finish` verb in `cmd_distill`, and two usage lines. No change to `record`/`next`/`bench`.
- Refusal order is markers before detachment (`MERGE_HEAD` -> `rebase-merge|rebase-apply` -> `CHERRY_PICK_HEAD` -> `REVERT_HEAD` -> detached HEAD): a real rebase also detaches HEAD, and "rebase in progress" is the more useful reason. `REVERT_HEAD` is in the list for the same reason `CHERRY_PICK_HEAD` is - git refuses a partial commit in both.
- `<n>` comes from `git diff --cached -- docs/chronicle` counting added lines containing ` · session · `; `distill.jsonl` is never read.
- A failed `git commit` leaves `docs/chronicle/` staged (the `git add` is not rolled back) - the files are uncommitted but ready; nothing outside the pathspec is touched either way.
- `git_error_line` takes git's first *non-empty, non-`warning:`* stderr line: on Windows `git commit` prefixes CRLF warnings, and "warning: in the working copy..." is not a reason.
- `tests/distill.test.sh`: F1-F11 in throwaway `git init` repos (`newrepo`/`put_record`/`refuses` helpers). Checked live: missing identity really fails here (`Author identity unknown`); a failing `pre-commit` hook blocks and a passing one runs (marker file), so `--no-verify` is provably absent.

## Findings
