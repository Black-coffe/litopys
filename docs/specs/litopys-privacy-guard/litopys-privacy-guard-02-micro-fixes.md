---
story: litopys-privacy-guard-02
spec: litopys-privacy-guard
status: done
returned: DONE
tier: 2
worker: worker-code
model: sonnet
wave: 2
blocked_by: [litopys-privacy-guard-01]
---

# Micro-defects from the recon

## Goal
The small, verified defects the recon listed are fixed, each with a test where behaviour changes.

## Requirements
> Микродефекты из разведки исправлены.
> И какие-то микродетальки, улучшения, если будешь замечать по ходу, тоже сделай.

## Files
- bin/litopys
- hooks/session-start.sh
- agents/recall.md
- tests/distill.test.sh
- tests/hooks.test.sh

## Non-goals
- No change to the privacy guard's contract (story 01), no version bump (story 03).
- No restructuring of `distill_next`'s eligibility/skip order; no new dependencies.

## Map slice
memory/map/litopys-plugin.md - Entry points (distill record/next), Gotchas.

## Acceptance criteria
- [ ] `distill record`: when a redactor exists but fails or prints nothing, the record is not written
      unfiltered - exit 2, journal left in place, reason on stderr.
- [ ] `distill record`: `date` and `sid8` taken from journal frontmatter are sanitised before they form
      the record path (no `/`, `..` or odd characters reach `docs/chronicle/sessions/`).
- [ ] `distill next` orders candidates by the ISO `started` string (portable), with an mtime fallback
      that needs no GNU-only `date -d` / `stat -c`.
- [ ] Stale-lock reclaim moves the old lock aside before `mkdir`, so two reclaimers cannot delete each
      other's fresh lock.
- [ ] `json_str` escapes control characters (tab, CR, LF), so `distill.jsonl` stays one valid row per line.
- [ ] The banner's chronicle count counts month files only (`golden-questions.md` excluded).
- [ ] Tests no longer use GNU-only `touch -d`.
- [ ] `agents/recall.md` no longer claims it has no tool that can write files.

## Verification
for t in tests/*.test.sh; do bash "$t" || exit 1; done

## Implementation notes
- `distill record`: a redactor that fails or prints nothing -> exit 2, nothing written, journal stays queued (was: unfiltered record written). New `record_rel` builds the record path for both `record` and `next`'s resumed-session check: date must look like a date (else the clock's, else zeros), id keeps `[A-Za-z0-9_-]` only.
- `distill next`: sort key is the ISO `started` string (text sort, `LC_ALL=C`), fallback `date -u -r <file>` (GNU, BSD, busybox); `date -d`/`stat -c` gone. Stale-lock reclaim renames the lock aside and re-checks what it moved; a fresh lock goes back.
- `json_str`: backslash, quote, tab, CR, LF escaped in pure bash, other control chars dropped. Surprise: bash 5.2 `patsub_replacement` ate an unquoted backslash in `${s//.../$bs$bs}` - replacements are now quoted; test P7 caught it.
- Banner counts month files only; `agents/recall.md` wording fixed; `touch -d` -> POSIX `touch -t`.
- Tests: P6 (failing redactor), P7 (hostile frontmatter + JSON escaping), banner fixture gains golden-questions.md.

## Findings
