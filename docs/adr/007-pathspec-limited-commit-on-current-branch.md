# ADR-007: Session records commit pathspec-limited on the current branch, not a chronicle branch

- Status: proposed; amended by ADR-010 (v0.3.0) - this commit now runs only under the owner's
  `LITOPYS_TRACK_CHRONICLE=1`; by default `distill finish` keeps records local
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-2-distill

## Context
From `plan.md` `## Assumptions`:
> **Records are committed on the current branch, path-limited** (brief Answer 3, narrows the roadmap's «мимо рабочих веток»): `distill finish` runs `git add -- <paths>` and `git commit -m "chore(chronicle): distill <n> session(s) [litopys]" -- <paths>` over exactly the record and month files this run wrote (manifest `.litopys/distill.paths`, wave 5 - originally the `docs/chronicle` directory pathspec, see `## Plan deltas`), so the host's staged and unstaged work - including host files under `docs/chronicle/` - is untouched. No separate chronicle branch or worktree.

And from `## Tradeoffs`:
> **Pathspec commit on the current branch vs. a chronicle branch** (Answer 3, listed under Assumptions for veto): recall reads the working tree; a branch it cannot see defeats the record.

And `## Plan deltas` (review round 1 major 3): the commit pathspec narrowed from the `docs/chronicle` directory to the exact manifest of paths `distill record` wrote, because the directory-wide pathspec swept an untracked host file (`golden-questions.md`) into the gate-A commit.

## Options
1. A separate chronicle branch or worktree, isolated from the host's working branch - rejected: `recall` reads the working tree, and a branch it cannot see defeats the record.
2. Pathspec-limited commit on the current branch, scoped to a directory (`docs/chronicle/`) - tried at gate A, swept in an untracked host file; superseded by option 3.
3. Pathspec-limited commit on the current branch, scoped to a run manifest of exact paths `distill record` wrote (`.litopys/distill.paths`) - chosen.

## Decision
`distill finish` commits only the exact paths recorded by `distill record` in the current run's manifest, on whatever branch is currently checked out. No chronicle branch or worktree is created. The commit refuses (leaving files uncommitted, printing the reason) on detached HEAD, an in-progress merge/cherry-pick/revert/rebase, or a failing `git commit` (no identity, a host pre-commit hook) - `--no-verify` is never used.

## Consequences
Session records are visible to `recall` immediately in the working tree, and the host's own staged/unstaged work - including other files under `docs/chronicle/` - is never touched, even when it shares a directory with plugin output. The cost is a second piece of state (the manifest file) that `record` must write correctly and `finish` must consume and delete; a bug in manifest bookkeeping under-commits or (if stale) over-commits.

## Invariants created
No plugin git operation may target anything outside the exact paths in `.litopys/distill.paths`; no plugin code creates or switches branches; `--no-verify` is never passed to `git commit`.

## Revisit when
A future phase wants records to survive on a different branch than the working one (e.g., for a bare-chronicle-repo host), or the manifest mechanism proves unreliable across concurrent runs.
