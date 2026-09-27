# litopys

Long-term project memory for [Claude Code](https://code.claude.com): a dated chronicle of your sessions,
kept in your repository's git, written by hooks without a model call. *Litopys* (літопис) is Ukrainian for
"chronicle".

- **Hooks keep a raw journal.** They write one Markdown file per session under `.litopys/raw/`,
  gitignored: your prompts, the assistant's last messages, compactions. No model is called and no
  network is used.
- **`/litopys:distill` turns closed journals into session records.** A Sonnet subagent writes
  `docs/chronicle/sessions/YYYY-MM-DD-<sid>.md`, which are committed. Text passes through a secret
  filter on its way into git.
- **`/litopys:recall <question>` answers from the project's history.** It reads the chronicle, specs,
  ADRs, changelog and git log, and returns an answer with file and commit refs.
- **`bin/litopys append` adds one dated line to `docs/chronicle/YYYY-MM.md`.** Other tools use it:
  [VULYK](https://github.com/Black-coffe/vulyk) records grills, briefs, verdicts and ships this way.

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

- New sessions start with a short banner: pending journals and the last chronicle entry.
- `/litopys:distill`: distill up to three closed journals into session records and commit them.
- `/litopys:recall what did we decide about X?`: an answer with refs, never a search transcript.
- `bin/litopys help`: the CLI (`append`, `distill`, `bench`).

What goes to git: `docs/chronicle/` (the monthly chronicle and distilled session records). What stays
local: `.litopys/` (raw journals, locks, cost logs).

## Develop

`claude --plugin-dir /path/to/litopys` loads a working copy. Tests are plain bash:
`bash tests/<name>.test.sh`. See `CHANGELOG.md`.

## License

MIT — see [LICENSE](LICENSE).
