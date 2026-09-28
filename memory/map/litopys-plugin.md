# Scout report: litopys plugin

## Purpose
Claude Code plugin (`.claude-plugin/plugin.json`, v0.3.0, loaded with `--plugin-dir`): a model-free
chronicle CLI, hooks that journal sessions, and a model-driven distill loop. Everything it
generates in a host is git-ignored by default (ADR-010).

## Entry points (`bin/litopys`, VERSION line 18)
- `append --kind <grill|brief|verdict|ship|handoff|note|session> --ref <r> [--note]` (C1-C3):
  one line into `docs/chronicle/YYYY-MM.md`, idempotent on `(ts, kind, ref)`; `cmd_append`
  is the only monthly-file writer (`session` comes from `distill record`).
- `privacy` (C17, `cmd_privacy`): takes no args; `ensure_private` maintains the managed block in
  `<root>/.gitignore` (status ok|added|updated|symlink|nogit|nogitbin|failed), then git judges
  it (`check-ignore --no-index` probes, `ls-files --others`, tracked-file count) and prints one
  line: `[litopys] privacy:` (fine) or `[litopys] PRIVACY:` (needs owner). Never touches the
  index; the untrack command is printed, not run. Always exit 0.
- `bench` / `bench --delta` (C4, C5, C15): five golden questions via `/litopys:recall` into
  `.litopys/baseline.jsonl`; `--delta` compares first 5 vs last 5 rows, <10 rows exits 2.
- `distill record --journal --body [--topics --links --source --model --force]` (C11/C13/C16):
  validates journal + four-section body, writes `docs/chronicle/sessions/<date>-<sid8>.md`
  (path from `record_rel`), one `session` chronicle line, manifest `.litopys/distill.paths`,
  journal to `raw/done/`, row in `distill.jsonl`. Exit 2 with nothing written on: existing
  record without `--force`, malformed input, or a redactor that fails/prints nothing.
- `distill next [--max N]` (C12): `mkdir distill.lock` mutex; stale (>30 min) lock is reclaimed by
  rename-then-recheck (a fresh one is moved back); eligibility (last block `## closed` or mtime
  >60 min) before the skip rule (no user / recall / distill first line -> `raw/skipped/`),
  resumed sessions -> `skipped/<sid>.resumed[.N].md`; prints up to N=3 oldest-first, sorted on
  ISO `started` (`date -r` mtime fallback); stderr `skipped · pending · selected`; exit 3
  `locked`. Lock released here only when nothing selected.
- `distill finish` (C12/C14/C17): default prints `kept local: <reason>` (git-ignored; reason
  says "NOT git-ignored - run bin/litopys privacy" if `check-ignore` disagrees), drops lock and
  manifest, no git write. With `LITOPYS_TRACK_CHRONICLE=1` commits only manifest paths
  (pathspec-limited, no -a/-A/--no-verify): `committed <sha7>` or `uncommitted: <reason>`.
  Always exit 0.
- `project_root()` (C1): `CLAUDE_PROJECT_DIR` -> git toplevel -> `$PWD`; hooks insert the
  payload `cwd` before git. `redactor()` (C16): host `scripts/redact.sh` -> plugin copy -> `cat`.
- `ensure_scratch <root>`: creates `.litopys/` + its `*` `.gitignore`; every `.litopys/` writer in
  the CLI calls it. `guard_private` = `ensure_private` + a stderr note; run by append, bench,
  distill record. `json_str` escapes per character (bash 3.2-5.2 safe).

## Key types / contracts
- C3 chronicle line, C16 redaction: `docs/wiki/chronicle-format.md`. C11 session record:
  `docs/wiki/session-record.md`. C4/C5/C15 bench: `bin/litopys` `BENCH_USAGE_JQ`, `DELTA_JQ`.
- **C17 managed block** (`privacy_block`): begin marker `# >>> litopys ...`, end `# <<< litopys <<<`,
  lines `.litopys/` and (unless tracking) `docs/chronicle/*` + `!docs/chronicle/golden-questions.md`.
  Only the last begin before the first end is rewritten; an unterminated begin is appended
  after, never swallowing the owner's file. Symlinked `.gitignore` is checked, never written.
- **C7/C8 raw journal** (`.litopys/raw/<sid>.md`): blocks `## user`, `## assistant`, `## closed`,
  `## compact · <ts> · <trigger>`; one file = one record (C13).
- **C9 banner**: six `[litopys]` lines: version, chronicle count, last entry, distill queue
  (`n` top-level `raw/*.md`), recall hint, line 6 = privacy line + " · never git add -f these
  paths" (omitted for nogit/nogitbin). Same privacy line is the top-level `systemMessage`.

## Hooks (`hooks/hooks.json`)
- `UserPromptSubmit`/`Stop` -> `raw-journal.sh prompt|stop` (timeout 10); `Stop` skips subagents.
- `SessionEnd` -> `raw-journal.sh end` (no timeout key; one `>>`, only into an existing journal).
- `PreCompact` -> `raw-journal.sh compact` (only into an existing journal).
- `SessionStart` -> `session-start.sh` (timeout 10): runs `bin/litopys privacy` with the resolved
  root every session; without jq it still runs the guard and emits a static jq-missing line.
- `raw-journal.sh` `ensure_journal` fails closed: no `.litopys/.gitignore` writable -> nothing
  journalled, checked on every block.
All run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` (Windows-safe, C2).

## Skill/agent pairs
- `/litopys:distill [N]` (`skills/distill/SKILL.md`, fork -> `agents/distiller.md`, sonnet):
  `distill next` -> Read journal, Write body to `.litopys/distill-<sid8>.body.md`, `distill
  record`, rm body -> `distill finish`. Agent never runs git or moves journals. Returns
  `**Distilled:**` / `**Skipped:**` / `**Commit:** <sha7>|kept local: <reason>|uncommitted:
  <reason>|locked|nothing pending` / `**Pending:**`.
- `/litopys:recall <q>` (fork -> `agents/recall.md`, sonnet; skill `allowed-tools: Read, Grep,
  Glob, Bash(git grep:*/log:*/tag:*/show:*)`). Order: `docs/chronicle/sessions/` ->
  `docs/chronicle/` -> `docs/specs/*/brief.md` -> `docs/adr/` -> `docs/grill/` -> `CHANGELOG*` ->
  tags -> log. Stages 1-2 use `git grep --no-index --no-exclude-standard -n -i -e <t> --
  docs/chronicle` because Grep skips ignored files. Returns Answer / Refs / Confidence.

## Tests
`tests/{append,bench,hooks,distill,privacy}.test.sh`; `privacy.test.sh` builds throwaway `git init`
repos and asserts .gitignore content, git's ignored/tracked view, the status line and an
untouched index. `claude-stub.sh` fakes `claude` for bench only. No suite calls a real model.

## Gotchas
- Root resolution (C1) is implemented separately in `bin/litopys` and both hooks: change all three.
- The guard reads git's verdict, not the block text: a later `!` rule or nested `.gitignore` shows
  as `NOT ignored`. `.gitkeep` files under `docs/chronicle/` were removed (ignored dirs).
- `distill next` eligibility runs before the skip rule (a live session's journal is never parked).
- `distill finish` commits manifest paths only, never a `docs/chronicle` sweep (opt-in mode).
- `tokens`/`tokens_est` are byte estimates `(journal+body)/4`; `BENCH_USAGE_JQ` sums cache tokens.
- `claude plugin validate . --strict` is red (root VULYK `CLAUDE.md` conflict); non-strict is used.

last-verified: 2026-09-29 (v0.3.0, spec litopys-privacy-guard, merge 3ac4f09)
