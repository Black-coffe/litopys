# litopys

Long-term project memory for [Claude Code](https://code.claude.com). Hooks keep a raw journal of every
session with no model call, a Sonnet subagent distills closed journals into short session records, and
`/litopys:recall` answers questions about the project's history with file and commit refs. Everything it
writes stays on your machine and out of git unless you opt in. *Litopys* (літопис) is Ukrainian for
"chronicle".

- **Hooks keep a raw journal.** One Markdown file per session under `.litopys/raw/`: your prompts, the
  assistant's last messages, compactions. No model is called and no network is used.
- **`/litopys:distill` turns closed journals into session records.** A Sonnet subagent writes
  `docs/chronicle/sessions/YYYY-MM-DD-<sid>.md` (decisions, problems, brainstorm, links). Every record
  passes a secret filter; if the filter fails, the record is refused rather than written unfiltered.
- **`/litopys:recall <question>` answers from the project's history.** It reads the session records,
  the chronicle, specs, ADRs, changelog and git log, and returns an answer with refs, never a search
  transcript.
- **`bin/litopys append` adds one dated line to `docs/chronicle/YYYY-MM.md`.** Other tools use it:
  [VULYK](https://github.com/Black-coffe/vulyk) records grills, briefs, verdicts and ships this way.

## Privacy: private by default

Raw journals are verbatim transcripts, and a session record is still a summary of a private
conversation that no secret filter can judge. So litopys keeps everything it generates out of git:

- **A managed block in your `.gitignore`.** Every session start, litopys makes sure the project's
  `.gitignore` carries this block, and rewrites it if it was edited:

  ```gitignore
  # >>> litopys - private session data, kept out of git by the litopys plugin >>>
  # rewritten every session; to commit the chronicle set LITOPYS_TRACK_CHRONICLE=1
  .litopys/
  docs/chronicle/*
  !docs/chronicle/golden-questions.md
  # <<< litopys <<<
  ```

  Nothing outside the block is touched. `.litopys/` also ignores itself, as a second fence.
- **Checked every session, and said out loud.** The check runs `git check-ignore` against the paths
  litopys writes. You get one line on screen, for example
  `[litopys] privacy: .litopys/ docs/chronicle/ git-ignored ✓`. The model gets the same line in its
  context, plus an instruction never to `git add -f` these paths.
- **Loud when something is wrong.** The line switches to `[litopys] PRIVACY:` when litopys had to add
  or repair the block, when a later `.gitignore` rule overrides it, or when git already tracks litopys
  files. For tracked files it prints the exact command to untrack them. It never runs that command
  itself, because untracking stages deletions on your branch. History you have already pushed stays
  on the remote.
- **Nothing is committed.** `/litopys:distill` writes the records and stops: `kept local`.
- **Opt in for a team chronicle.** Set `LITOPYS_TRACK_CHRONICLE=1` (for example under `env` in
  `.claude/settings.json`). The block then covers `.litopys/` only, and `/litopys:distill` commits the
  records it wrote on the current branch, never your other staged or unstaged work. `.litopys/`
  stays private either way.

Outside a git repository there is nothing to leak into, so no `.gitignore` is written.

## Install

In a project, from your shell:

```bash
claude plugin marketplace add Black-coffe/litopys --scope project
claude plugin install litopys@litopys --scope project
```

`--scope project` writes the plugin into `.claude/settings.json`. Commit that file, and everyone who
trusts the folder gets litopys too. Leave the flag out to install it for yourself only.

Requirements: `bash` (Git Bash on Windows), `jq` and `git`.

## Use

- New sessions start with a short banner: pending journals, the last chronicle entry, and the privacy
  line.
- `/litopys:distill`: distill up to three closed journals into session records (`/litopys:distill 5`
  for more).
- `/litopys:recall what did we decide about X?`: an answer with refs.
- `bin/litopys privacy`: run the privacy check by hand.
- `bin/litopys corrections [--since YYYY-MM-DD] [--lexicon <file>]`: the owner's corrections, quoted verbatim
  from session records. With a lexicon you pass in, it also shows matching lines of your own words in the raw
  journals. It is read-only and makes no model call.
- `bin/litopys help`: the whole CLI (`append`, `corrections`, `distill`, `privacy`, `bench`).

Environment: `LITOPYS_TRACK_CHRONICLE=1` (commit the chronicle instead of ignoring it),
`CLAUDE_PROJECT_DIR` (project root override).

## Develop

`claude --plugin-dir /path/to/litopys` loads a working copy. Tests are plain bash; run them all with
`for t in tests/*.test.sh; do bash "$t" || exit 1; done`. See `CHANGELOG.md`.

## License

MIT — see [LICENSE](LICENSE).
