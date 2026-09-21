---
story: litopys-phase-2-distill-04
spec: litopys-phase-2-distill
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 2
blocked_by: [litopys-phase-2-distill-01]
---

# `bin/litopys distill next` - lock, skip rule, eligibility, cap N=3

## Goal
`bash bin/litopys distill next [--max N]` implements C12: takes the `mkdir .litopys/distill.lock` mutex (reclaiming a lock older than 30 minutes, otherwise `locked` on stderr and exit 3), moves every top-level journal whose first `## user` line starts with `/litopys:recall` or `/litopys:distill` to `.litopys/raw/skipped/`, then prints up to N (default 3) eligible journal paths oldest first on stdout and one `skipped <s> · pending <p> · selected <k>` line on stderr, releasing the lock itself only when it selected nothing. Story 05's `finish` releases it otherwise.

## Requirements
> redact; коммит мимо рабочих веток; lock + cap N очереди
> phase 2's distiller skips `## user` blocks whose first line starts with `/litopys:recall`
> `mkdir .litopys/distill.lock` as the mutex (atomic on every shell), stale after 30 minutes; at most N=3 journals per run, oldest first, so a backlog of bench journals never eats a session start; journals whose first `## user` line starts with `/litopys:recall` or `/litopys:distill` are skipped and moved to `.litopys/raw/skipped/`, never distilled

## Files
- bin/litopys
- tests/distill.test.sh
- tests/fixtures/raw-bench.md

## Non-goals
- No git, no commit, no lock release path other than the "selected nothing" case (`distill finish` is story 05 - do not pre-build it, not even a stub arm).
- Do not change `distill record` (story 01) beyond what `next` needs; do not change `append` or `bench`.
- Do not inspect journal content beyond the frontmatter `started` line, the first `## user` block's first content line, and the last `## ` header - no parsing of assistant text.
- Do not delete anything: skipped journals are moved, never removed; `done/` is written only by `record`.
- No PID liveness check, no `flock`, no lock file other than the directory and its `owner` line.
- Do not touch hooks, `agents/`, `skills/`, `plugin.json`.

## Map slice
`memory/map/litopys-plugin.md` - Entry points (CLI), C1, C8; `recon/plugin.md` Q2 (`project_root()`, dispatcher) and Q4 (test pattern, `mktemp -d` + `trap`); `recon/host-and-journal.md` "Raw journal format" (15 of 17 real journals start with `/litopys:recall`); plan.md C12, C13 (eligibility reads the last `## ` header), story 01's `Implementation notes` for the parser helpers it left in `bin/litopys`.

## Acceptance criteria
- [ ] `tests/fixtures/raw-bench.md` is a C8 journal whose first `## user` block begins `/litopys:recall what is ...`, ending in `## closed`.
- [ ] Temp project with five journals - two bench (one `/litopys:recall`, one `/litopys:distill` first line), three normal with distinct `started` values, all ending in `## closed`: `distill next` prints the three normal paths oldest-first by `started` (not by filename), stderr `skipped 2 · pending 3 · selected 3`, both bench files are in `.litopys/raw/skipped/`, `.litopys/distill.lock/owner` exists.
- [ ] `--max 1` prints one path; four eligible journals with the default cap print three and `pending 4 · selected 3`.
- [ ] A journal whose last `## ` header is `## user` (open session) with a fresh mtime is not printed and counts as pending; the same file with mtime set 61 minutes back (`touch -d '61 minutes ago'` or `touch -t`) is printed. A journal without any `## user` block is treated as normal, not skipped.
- [ ] A journal with `## closed` mid-file followed by more blocks and a final `## closed` is eligible and is printed once (one file = one session).
- [ ] Second `next` while the lock is fresh: stderr `locked`, exit 3, stdout empty, no file moved; with the lock dir aged 31 minutes it is reclaimed and the run proceeds.
- [ ] `next` on a project with no top-level journals: exit 0, stdout empty, stderr `skipped 0 · pending 0 · selected 0`, and no lock left behind. `next` with only skippable journals: they are moved, then same as empty.
- [ ] Idempotence with `record`: after `record` moves a printed journal to `done/`, a following `next` (lock reclaimed or released) does not list it.
- [ ] Every file LF; no model call; `bash -n bin/litopys` clean.

## Verification
`bash tests/distill.test.sh`

## Implementation notes

## Findings
