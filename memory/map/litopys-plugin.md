# Scout report: litopys plugin

## Purpose
Claude Code plugin (`.claude-plugin/plugin.json`, v0.4.0, loaded with `--plugin-dir`): a model-free
chronicle CLI, hooks that journal sessions, and a model-driven distill loop. Everything it
generates in a host is git-ignored by default (ADR-010).

## Entry points (`bin/litopys`, VERSION line 18)
- `append --kind <grill|brief|verdict|ship|handoff|note|session> --ref <r> [--note]` (C1-C3):
  one line into `docs/chronicle/YYYY-MM.md`, idempotent on `(ts, kind, ref)`; `cmd_append`
  is the only monthly-file writer (`session` comes from `distill record`).
- `corrections [--since YYYY-MM-DD] [--lexicon <file>]` (`cmd_corrections`): read-only, exit 0. Prints
  `<date> · <sid8> · record · «q»` per `## Corrections` line of `sessions/*.md`; with a consumer-
  supplied ERE lexicon also `... · lexicon · «line»` for matching `## user` lines of
  `.litopys/raw/` + `raw/done/` (`human_lines`; `## notice` never read). Bad `--since`/no lexicon: exit 2.
- `privacy` (C17, `cmd_privacy`): no args; `ensure_private` maintains the managed block in
  `<root>/.gitignore` (ok|added|updated|symlink|nogit|nogitbin|failed), git then judges it
  (`check-ignore --no-index`, `ls-files --others`, tracked count); one line `[litopys] privacy:`
  or `[litopys] PRIVACY:`. Never touches the index; untrack command printed, not run. Exit 0.
- `bench` / `bench --delta` (C4, C5, C15): five golden questions via `/litopys:recall` into
  `.litopys/baseline.jsonl`; `--delta` compares first 5 vs last 5 rows, <10 rows exits 2.
- `distill record --journal --body [--topics --links --source --model --force]` (C11/C13/C16):
  validates journal + five-section body (Decisions, Corrections, Problems, Brainstorm, Links) and
  every «quote» (Decisions: first « to last »; Corrections: `- «q» — what` or `- (none)`) as a
  whitespace-normalised substring of `## user` text (ADR-011); writes `sessions/<date>-<sid8>.md`
  (`record_rel`), one `session` chronicle line, `.litopys/distill.paths`, journal to `raw/done/`,
  row in `distill.jsonl`. Exit 2, nothing written: record exists without `--force`, malformed
  input or quote, or a redactor that fails/prints nothing.
- `distill next [--max N]` (C12): `mkdir distill.lock` mutex, stale (>30 min) reclaimed by
  rename-then-recheck; eligibility (last block `## closed` or mtime >60 min) before the skip rule
  (no user / recall / distill first line -> `raw/skipped/`; resumed -> `skipped/<sid>.resumed[.N].md`);
  prints up to N=3 oldest-first on ISO `started`; stderr `skipped · pending · selected`; exit 3 `locked`.
- `distill finish` (C12/C14/C17): default prints `kept local: <reason>`, drops lock and manifest, no
  git write. With `LITOPYS_TRACK_CHRONICLE=1` commits only manifest paths (no -a/-A/--no-verify):
  `committed <sha7>` or `uncommitted: <reason>`. Always exit 0.
- `project_root()` (C1): `CLAUDE_PROJECT_DIR` -> git toplevel -> `$PWD` (hooks put payload `cwd`
  before git). `redactor()` (C16): host `scripts/redact.sh` -> plugin copy -> `cat`.
- `ensure_scratch <root>` makes `.litopys/` + its `*` `.gitignore`; `guard_private` = `ensure_private`
  + stderr note (append, bench, distill record). `json_str` escapes per character (bash 3.2-5.2).

## Key types / contracts
- C3 chronicle line, C16 redaction: `docs/wiki/chronicle-format.md`. C11 session record:
  `docs/wiki/session-record.md`. C4/C5/C15 bench: `bin/litopys` `BENCH_USAGE_JQ`, `DELTA_JQ`.
- **C17 managed block** (`privacy_block`): begin marker `# >>> litopys ...`, end `# <<< litopys <<<`,
  lines `.litopys/` and (unless tracking) `docs/chronicle/*` + `!docs/chronicle/golden-questions.md`.
  Only the last begin before the first end is rewritten; an unterminated begin is appended
  after, never swallowing the owner's file. Symlinked `.gitignore` is checked, never written.
- **C7/C8 raw journal** (`.litopys/raw/<sid>.md`): blocks `## user`, `## assistant`, `## closed`,
  `## compact · <ts> · <trigger>`, `## notice · <ts> · <kind>` (task-notification|system-reminder|
  cross-session|pasted; harness segments cut from a prompt by `NOTICE_RE` in `journal_prompt`,
  written after the `## user` remainder); one file = one record (C13).
- **C9 banner**: six `[litopys]` lines (version, chronicle count, last entry, distill queue, recall
  hint, privacy line); the privacy line is also the top-level `systemMessage`.

## Hooks (`hooks/hooks.json`)
- `UserPromptSubmit`/`Stop` -> `raw-journal.sh prompt|stop` (timeout 10); `Stop` skips subagents.
- `SessionEnd` -> `raw-journal.sh end` (no timeout key; one `>>`, only into an existing journal).
- `PreCompact` -> `raw-journal.sh compact` (only into an existing journal).
- `SessionStart` -> `session-start.sh` (timeout 10): runs `bin/litopys privacy` with the resolved
  root every session; without jq it still runs the guard and emits a static jq-missing line.
- `ensure_journal` fails closed (no writable `.litopys/.gitignore` -> nothing journalled).
All run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` (Windows-safe, C2).

## Skill/agent pairs
- `/litopys:distill [N]` (`skills/distill/SKILL.md`, fork -> `agents/distiller.md`, sonnet):
  `distill next` -> Read journal, Write body to `.litopys/distill-<sid8>.body.md`, `distill
  record`, rm body -> `distill finish`. Agent never runs git or moves journals. Returns
  `**Distilled:**` / `**Skipped:**` / `**Commit:** <sha7>|kept local: <reason>|uncommitted:
  <reason>|locked|nothing pending` / `**Pending:**`.
- `/litopys:recall <q>` (fork -> `agents/recall.md`, sonnet; read-only tools + `git grep/log/tag/show`).
  Order: `sessions/` -> `docs/chronicle/` -> specs briefs -> `docs/adr/` -> `docs/grill/` ->
  `CHANGELOG*` -> tags -> log. Stages 1-2 use `git grep --no-index --no-exclude-standard`
  (Grep skips ignored files). Returns Answer / Refs / Confidence.

## Tests
`tests/{append,bench,hooks,distill,privacy}.test.sh` (`distill.test.sh` covers the quote checks via
`tests/fixtures/distill-body.md`, which carries `## Corrections` and no quotes); `claude-stub.sh`
fakes `claude` for bench only. No suite calls a real model.

## Gotchas
- Root resolution (C1) is implemented separately in `bin/litopys` and both hooks: change all three.
- The guard reads git's verdict, not the block text: a later `!` rule shows as `NOT ignored`.
- `distill next` eligibility runs before the skip rule (a live session's journal is never parked).
- Journals written before 0.4.0 keep harness text in `## user`; the quote check is weaker there.
- `tokens_est` is a byte estimate `(journal+body)/4`; `BENCH_USAGE_JQ` sums cache tokens.
- `claude plugin validate . --strict` is red (root VULYK `CLAUDE.md` conflict); non-strict is used.

last-verified: 2026-09-30 (v0.4.0, spec correction-evidence, merge cc0b8fd)
