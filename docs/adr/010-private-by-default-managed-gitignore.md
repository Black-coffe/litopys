# ADR-010: Private by default - a managed block in the host's .gitignore, checked every session

- Status: accepted
- Date: 2026-09-29
- Spec: docs/specs/litopys-privacy-guard
- Supersedes: ADR-004's invariant "no plugin code writes to a host's `.gitignore`"; amends ADR-007
  (the commit becomes opt-in)

## Context
The owner, 2026-09-28 (brief, verbatim): «Самое главное в плане безопасности — всё, что он генерирует
в тех проектах, в которых он установлен, должно автоматически попадать в [.gitignore]. Он должен это
контролировать, об этом говорить, напоминать и в каждой сессии перепроверять.»

Until 0.2.1, `.litopys/` was protected only by its own `.litopys/.gitignore` (`*`), which several
`.litopys/` writers never created themselves (they relied on another writer having run first), and
`docs/chronicle/` was git-tracked by design:
`distill finish` committed every record. In a public repository that pushes summaries of private
conversations. The redactor catches key patterns, not content.

## Options
1. Only `.litopys/` goes into the host `.gitignore`; the chronicle stays committed.
2. Everything is ignored, and the commit path is removed.
3. Everything is ignored by default, and the commit path stays behind an explicit opt-in. Chosen
   (grill answer 1).

## Decision
- `bin/litopys privacy` owns one block in `<root>/.gitignore`: `.litopys/` (unanchored),
  `docs/chronicle/*`, and `!docs/chronicle/golden-questions.md` (written by the owner, not generated).
  The block is found by marker prefix, taken as the last begin marker before the first end marker,
  and rewritten only when its content differs from what the mode wants. Nothing outside it is written.
- `SessionStart` runs the guard every session. It verifies the result with
  `git check-ignore --no-index` and lists tracked-but-private files with
  `git ls-files -ci --exclude-standard`. It reports one line to the owner (`systemMessage`) and the
  model (banner line 6, "never git add -f these paths"). Tracked files get the untrack command,
  printed and never run (grill answer 2).
- `append`, `distill record` and `bench` ensure the block too, for CLI runs outside a session.
- `distill finish` prints `kept local: ...` by default. `LITOPYS_TRACK_CHRONICLE=1` drops
  `docs/chronicle/*` from the block and restores ADR-007's pathspec-limited commit unchanged.
- A root that is not a git work tree gets no `.gitignore`.

## Consequences
The plugin now edits a file the owner owns. That is bounded by the markers and announced every time
it happens (`[litopys] PRIVACY: added ...`), so the owner commits the change knowingly. A team that
relied on 0.2.x committing records must set the opt-in. Records already committed by 0.2.x stay
tracked until the owner runs the printed command, and the warning repeats until then.

Recall had to change. Claude Code's `Grep` is ripgrep, and ripgrep skips git-ignored files: with the
block in place it finds neither month files nor session records, from the project root or from
`docs/chronicle/` (review round 1, verified with rg 14.1.1 and the Grep tool). `agents/recall.md` and
the skill now search stages 1-2 with `git grep --no-index --no-exclude-standard`, which reads ignored
files (verified on git 2.55; `tests/privacy.test.sh` G11 runs that exact command against an ignored
chronicle). `Glob` and `Read` are unaffected.

## Invariants created
Nothing litopys generates enters git unless `LITOPYS_TRACK_CHRONICLE=1`, and `.litopys/` never does.
The guard never writes the index. Only the managed block is ever rewritten, and a symlinked
`.gitignore` is never written through. Every `.litopys/` writer in `bin/litopys` goes through
`ensure_scratch`; `hooks/raw-journal.sh` keeps its own fail-closed copy (hooks do not source the CLI,
ADR-003). Recall searches `docs/chronicle/` with a command that reads ignored files.
The printed untrack command is `git ls-files -ci ... | xargs -0 git rm --cached` over exactly the
counted pathspecs, never `git rm -r --cached` on a directory: that keeps `golden-questions.md`
tracked (amendment, proposed - plan delta 3 of 2026-09-29, review minor 13; owner to accept).

## Revisit when
Claude Code offers a per-plugin data directory outside the project tree for the raw journal, or a
host needs the chronicle somewhere other than `docs/chronicle/`.
