# litopys phase 2: distillation (plan)

**Tier:** 3 · **Spec slug:** `litopys-phase-2-distill` · **Brief:** [brief.md](brief.md)
**Governed by:** grill `docs/grill/2026-09-21-project-memory-chronicle.md` (D1-D15, Act 2, Roadmap v2 phase 2); scouts `recon/plugin.md`, `recon/host-and-journal.md`; `docs/wiki/chronicle-format.md` (C3, C8); CLAUDE.md `## Profile` (bash-only, Windows Git Bash primary, no model calls in hooks)
**Depends on:** `litopys-phase-0-1` (v0.1.0, merged `efedfce`) - contracts C1-C10 in its plan.md; this plan extends them with C11-C16 and amends C3, C7, C8, C9 where stated.

## Goal
Turn the raw journals phase 1 leaves in `.litopys/raw/` into git-tracked session records without a model ever running inside a hook. A `/litopys:distill` skill forks a sonnet `distiller` agent; the agent reads up to three closed journals (oldest first, behind a `mkdir` lock), writes each one's decisions / problems / brainstorm / links as a body, and hands the body to `bin/litopys distill record`, which builds the flat record `docs/chronicle/sessions/YYYY-MM-DD-<sid8>.md` with frontmatter, redacts it, appends one `session` line to the monthly chronicle, and moves the journal to `.litopys/raw/done/`. `bin/litopys distill finish` commits only the paths this run wrote on the current branch and releases the lock. Bench/recall journals are skipped into `.litopys/raw/skipped/`. A `PreCompact` hook marks compactions in the journal; the SessionStart banner's line 4 says how many journals wait. Redaction no longer depends on the host: `--note`, `--ref` and every record pass through the host's `scripts/redact.sh` or the plugin's own copy. `bench --delta` prints the latest golden-question run against the phase-0 baseline; the phase closes on that line, measured in VULYK after its real journals are distilled.

**Tier justification:** cross-cutting over the CLI, both hook scripts, `hooks.json`, a new agent/skill pair, the recall pair and three test suites; six contracts cross story boundaries; two real-world gates in a host repo; six stories over four waves, plus a fifth wave of two review-fix stories.

## Assumptions
<!-- Law 1: each line is vetoable at the approval stop. -->
- **Records are committed on the current branch, path-limited** (brief Answer 3, narrows the roadmap's «мимо рабочих веток»): `distill finish` runs `git add -- <paths>` and `git commit -m "chore(chronicle): distill <n> session(s) [litopys]" -- <paths>` over exactly the record and month files this run wrote (manifest `.litopys/distill.paths`, wave 5 - originally the `docs/chronicle` directory pathspec, see `## Plan deltas`), so the host's staged and unstaged work - including host files under `docs/chronicle/` - is untouched. No separate chronicle branch or worktree. It refuses (leaves files uncommitted, prints the reason) on: not a git repo, detached HEAD, `MERGE_HEAD`/`CHERRY_PICK_HEAD`/`REVERT_HEAD`/`rebase-merge`/`rebase-apply` present, or `git commit` itself failing (no identity, a host pre-commit hook). Host commit hooks are not bypassed (`--no-verify` is not used).
- **Banner line 4 is repurposed, still five lines** (Answer 2): `[litopys] distill: <n> pending · run /litopys:distill` when `n ≥ 1`, `[litopys] distill: nothing pending` when `n = 0`. The threshold is 1 - with N=3 and bench journals skipped in bulk, a lower threshold has nothing to hide. `n` counts `.litopys/raw/*.md` at the top level only (`done/`, `skipped/` excluded). Accepted consequence (review minor 12): the count includes the running session's own open journal, so a `--resume` may show `1 pending` that the run then reports as nothing pending.
- **Distillation is skill-driven, never background** (Answer 2): no hook starts a model, spawns `claude -p`, or forks anything; SessionStart only counts. PreCompact only appends a marker. This is the letter of Ask 10.
- **N=3 per run, oldest first** (Answer 4); the skip rule runs over the whole *eligible* backlog before the cap, so one run clears every closed bench journal. A journal whose session may still be running is never moved (wave 5).
- **`tokens` in the record and `tokens_est` in `.litopys/distill.jsonl` are byte-based estimates** (`(journal_bytes + body_bytes) / 4`): a forked agent cannot read its own usage. The real cost of one distillation run is measured once, at gate A, from the `claude -p --output-format json` envelope, and recorded on the gate line (D12's ≤5% check). Rejected: a CLI-driven `claude -p` distiller for exact cost - Answer 2 fixed the fork.
- **A distilled journal moves to `.litopys/raw/done/<sid>.md`** (kept indefinitely, gitignored, re-distillable with `--force`), so "pending" is simply what is left at the top level. Rejected: a `.distilled` marker file per journal - a second thing to keep in sync.
- **Eligibility:** `distill next` offers a journal only if its last `## ` block is `## closed`, or its mtime is older than 60 minutes (a crashed session never gets `## closed`). A running session's journal is never distilled under it - and, since wave 5, never skipped or parked under it either.
- **A resumed session whose record already exists is parked, not merged** (wave 5, review major 4): `next` moves it to `skipped/<sid>.resumed.md` and counts it as skipped; the resume's content is not chronicled in phase 2 (the file stays on disk for a hand `--force` or the phase-5 backfill). Rejected: a `record --merge` - the agent would see only the resume fragment, and a merged body needs a model reading both halves. Vetoable by the owner.
- **Re-distilling an existing record needs `--force`**; without it `distill record` exits 2 and writes nothing (an accidental second run must not append a second chronicle line).
- **`session` joins C3's kind list** (`grill|brief|verdict|ship|handoff|note|session`); `distill record` appends the chronicle line through `cmd_append`'s own code path, so the monthly file keeps one writer (D13).
- **No `tests/lib.sh` this phase**: only one new suite appears (`tests/distill.test.sh`); the tracer copies the four helpers a fourth time. Extracting now would touch all three existing suites in wave 1 and collide with stories 02 and 06. Phase 3 (validate + recall changes) adds at least two suites and does the extraction.
- **Ask 10's «ничего не пишется в CLAUDE.md» is read as a runtime constraint on the plugin**, as in phase 0-1 - and, learning from the phase-0-1 UNASKED (2), no story in this plan needs a new `## Commands` row: every `## Verification` is an existing `bash tests/<name>.test.sh`, the existing build command, or (story 08) a grep over the one file it edits.
- **The 0.2.0 version bump rides in story 06** (the last story touching `bin/litopys`): `VERSION`, `.claude-plugin/plugin.json`, the `CHANGELOG.md` `[0.2.0]` section and the version literals the tests assert. Law 5 forbids the Queen doing it by hand once the story files exist. Recon question 1 decides whether `hooks/session-start.sh` also carries a literal.
- **The plugin's `scripts/redact.sh` stays VULYK's file verbatim, mask `[VULYK:REDACTED]` included**; only the header's caller names change (Answer 5). It silently degrades to `cat` without `sed`/`awk` - inherited, documented in the story, not fixed.
- **PreCompact payload:** the field is `compaction_trigger` (`"manual"`|`"auto"`) per the official hooks reference (code.claude.com/docs/en/hooks, read 2026-09-21; the PreCompact matcher filters on the same value); the hook reads `.compaction_trigger // .trigger // "-"` and tolerates absence - the marker is written either way. Second source: the installed CLI 2.1.278 was not grepped to completion (bundle too large); mark as confirmed by one primary source plus the matcher semantics.
- **Recon answers folded in (Queen, 2026-09-21):** `hooks/session-start.sh:36-37` reads the version from `.claude-plugin/plugin.json` with a `0.1.0` literal fallback only - story 06 updates that fallback literal and nothing else in the hook; `count_md` (`session-start.sh:39-42`) is top-level only, so `done/` and `skipped/` subdirectories never inflate the pending count; `tests/hooks.test.sh` asserts `hooks.json` is valid JSON and per-event timeouts, not the number of event keys - a fifth key needs a new assertion, not a fix.
- **Ask 10 re-asserted for the new work (coverage check):** SessionEnd keeps its single `journal_end()` write and its under-one-second budget - PreCompact is a separate event with a 600 s default timeout and the pending count runs at SessionStart, never at SessionEnd; `tests/hooks.test.sh` keeps the one-`>>` assertion on `journal_end()`. `agents/recall.md` keeps `model: sonnet` after story 03 adds the `docs/chronicle/sessions/` stage (story 03 acceptance), and `agents/distiller.md` is `model: sonnet` by D12.
- **Gate A runs `claude -p` in VULYK with `--permission-mode acceptEdits`** so the forked agent's `Write`/`Bash` calls are not auto-denied in print mode (recon question 4 confirms the flag; the interactive fallback is stated on the gate line).

## Stories

**Wave 1**
- `litopys-phase-2-distill-01-tracer-distill-record` (opus, tracer) - `bin/litopys distill record`: one raw journal + one body file -> one C11 record + one `session` chronicle line + journal moved to `done/` + one `distill.jsonl` row, redacted via C16; the resume/compact parser rule (C13); `append --ref` collapsed and redacted; `scripts/redact.sh` header; `tests/distill.test.sh`, `tests/append.test.sh`, fixtures.
- `litopys-phase-2-distill-02-hooks-precompact-banner` (sonnet) - `PreCompact` -> `raw-journal.sh compact` (`## compact · <ts> · <trigger>`); banner line 4 = pending count; `tests/hooks.test.sh`.

**Wave 2** (blocked by 01)
- `litopys-phase-2-distill-03-distiller-agent-skill` (opus) - `agents/distiller.md` (sonnet) + `skills/distill/SKILL.md` (`context: fork`) implementing C14; `agents/recall.md` + `skills/recall/SKILL.md` gain `docs/chronicle/sessions/` as search stage 1.
- `litopys-phase-2-distill-04-distill-queue-lock` (sonnet) - `bin/litopys distill next`: `mkdir` lock, 30-min stale, skip rule -> `skipped/`, eligibility, cap N=3 oldest first (C12); tests.

**Wave 3** (blocked by 04)
- `litopys-phase-2-distill-05-distill-finish-commit` (opus) - `bin/litopys distill finish`: pathspec commit on the current branch with the refusal list, lock release; git-state tests in throwaway repos.

**Gate A (Queen/owner, terminal, after wave 3 - inside E:/Projects/vulyk, nothing in this repo's stories writes there):**
```
cd E:/Projects/vulyk && claude -p --plugin-dir E:/Projects/litopys --model sonnet --output-format json --permission-mode acceptEdits "/litopys:distill" > .litopys/distill-gate-a.json; git -C E:/Projects/vulyk log -1 --stat; ls .litopys/raw .litopys/raw/skipped .litopys/raw/done; cat .litopys/distill.jsonl
```
Expected: 15 bench journals in `.litopys/raw/skipped/`, `a10ea931-...` and `ac90b6ae-...` in `.litopys/raw/done/`, two records in `docs/chronicle/sessions/`, two `· session ·` lines in `docs/chronicle/2026-09.md`, one commit touching only `docs/chronicle/`, two `distill.jsonl` rows; `total_cost_usd` and usage from the JSON envelope are written on this line as the measured cost of distilling a10ea931 (the ≥100k session). Fallback if print mode cannot run the fork: `claude --plugin-dir E:/Projects/litopys` interactively in VULYK, `/litopys:distill`, cost read from `/cost`.

**Result (gate A, 2026-09-21 16:04Z, run by the Queen):** `Distilled: 2` (`2026-09-21-ac90b6ae.md` Hook smoke test; `2026-09-21-a10ea931.md` Chronicle location decision and a telemetry.sh bug found), `Skipped: 16` -> `.litopys/raw/skipped/`, commit `ba151a2` in VULYK touching only `docs/chronicle/` (2026-09.md +4, golden-questions.md, two records), two `distill.jsonl` rows (`tokens_est` 111 and 2864), `Pending: 0`. Envelope: `total_cost_usd` 0.285, `num_turns` 0, usage all zero (fork usage not surfaced in print mode, as assumed). The a10ea931 record carries Decisions / Problems / Brainstorm / Links with the real telemetry.sh:90 finding and the three chronicle-home options. Two defects surfaced here and became review critical 1 and major 3 (wave 5): the running distill session's own journal (`ffab22c9`, first line `/litopys:distill`) was moved to `skipped/` mid-session and re-created by the next Stop hook; and `golden-questions.md`, an untracked host file under `docs/chronicle/`, was swept into commit `ba151a2`. VULYK's own `anomaly-scan.sh` SessionEnd hook reported "Hook cancelled" on stderr, unrelated to the plugin.

**Wave 4** (blocked by 05)
- `litopys-phase-2-distill-06-bench-delta-release` (sonnet) - `bench --delta` (C15); Ask 9 hardening (jq comment, snake/camel per-object, all-zero `usage` test, `error` key on unparsable stdout); version 0.2.0 + CHANGELOG.

**Gate B (Queen/owner, terminal, after wave 4 - inside E:/Projects/vulyk, after gate A):**
```
cd E:/Projects/vulyk && bash E:/Projects/litopys/bin/litopys bench && bash E:/Projects/litopys/bin/litopys bench --delta
```
Expected: five new rows appended to `.litopys/baseline.jsonl` (rows 1-5 remain the 14:01:10Z phase-0 baseline) and one C15 line; that line is the phase's «delta vs baseline» and is copied here.
**Result (gate B, 2026-09-21 16:12Z, run by the Queen):** `hits 4/5 · refs 6/8 · 142s`; C15 line: `delta vs baseline · hits 4/5 -> 4/5 (+0) · refs 7/8 -> 6/8 (-1) · seconds 143 -> 142 (-1) · tokens_in 1087178 -> 1220744 (+12%) · tokens_out 6161 -> 6525 (+5%) · cost_usd 0.7816551 -> 0.7651865 (-2%)`. Rows 6-10 appended, rows 1-5 untouched. Reading: no gain yet, and none was possible - the two distilled sessions are about the plugin itself, while the five golden questions ask about VULYK history from before the plugin existed; the delta becomes meaningful once phase 5 backfills or once real VULYK sessions accumulate. The -1 ref is Q1 (2/2 -> 1/2) - run-to-run variance of recall, not a regression the records could cause (they do not mention Q1's refs). D15's switch-off criterion is therefore not triggered by this run and not satisfied either; it is re-measured at phase 3.

**Wave 5** (blocked by 06 - council round 1 fixes, `council/round-1/review.md` BLOCK)
- `litopys-phase-2-distill-07-next-finish-review-fixes` (opus) - critical 1 + majors 2, 3, 4, all in `bin/litopys` + `tests/distill.test.sh` (one file, one wave, therefore one story): skip rule only over eligible journals, user-less journal skipped; ordering list without `printf %b`; `record` writes the run manifest `.litopys/distill.paths`, `finish` commits exactly those paths; resumed-after-distill journal parked in `skipped/<sid>.resumed.md`.
- `litopys-phase-2-distill-08-wiki-chronicle-format` (sonnet) - major 5: `docs/wiki/chronicle-format.md` states C3 amended (seven kinds, ref normalisation + redaction, host-then-plugin redactor), the `## compact` block and the C13 reading.

Gate A is re-run after wave 5 in a VULYK checkout with the resumed-fragment journal present (expected: `ffab22c9`-style fragment skipped, no new fragment created, the commit's `--stat` lists only the record and month file). Gate B is not re-run - nothing in wave 5 touches `bench`.

**Result (gate A re-run, 2026-09-21 16:5xZ, wave-5 code, run by the Queen):** `Distilled: 0`, `Skipped: 6` (the `ffab22c9` fragment plus the five journals of gate B's bench run), `Commit: nothing pending`, `Pending: 1` = the running session's own open journal, left in place and not distilled; no new fragment created, `distill.jsonl` unchanged at two rows, VULYK HEAD still `ba151a2`. Cost 0.164 USD. Behaviour matches critical 1's condition.

Build agent count: 8 workers (4 opus: 01, 03, 05, 07; 4 sonnet: 02, 04, 06, 08) + full court (`council-sonnet`, `council-opus`, `council-haiku`) + `lead-review` = 12 dispatches, plus retries (a missed sonnet story retries on opus).

## Contracts

**C3 (amended: 01).** `kind` ∈ `grill|brief|verdict|ship|handoff|note|session`. `--ref` is normalised before use: `\n`, `\r`, `\t` -> space, the sequence ` · ` -> ` - `, then piped through the C16 redactor exactly like `--note`. A ref that is empty after normalisation is a usage error (exit 2). Idempotence stays `(ts, kind, ref)` on the normalised ref.

**C7 (amended: 02).** `hooks/hooks.json` gains
```json
"PreCompact":[{"hooks":[{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/raw-journal.sh\" compact","timeout":10}]}]
```
Five events; SessionEnd still the only one without `timeout`; `journal_end()` untouched (its single `>>` assertion stands).

**C8 (amended: 02 writes, 01 reads) / C13 - compaction marker and resumed sessions.** New block, appended by `compact` only if the journal already exists (same guard as `## closed`), in its own `journal_compact()`:
```
## compact · <UTC ISO> · <compaction_trigger: manual|auto|->
```
Parser rule (`distill record`, and the distiller's prompt): **one journal file = one session record**, whatever the number of `## closed` and `## compact` blocks. `## closed` followed by more blocks means a process exit and a resume; the record spans all blocks; frontmatter `ended` = ts of the last `## closed` when it is the file's last block, else `-`. `## compact` means the assistant's context was summarised at that point - the distiller treats blocks after it as the same session with reduced memory of the earlier ones. Neither marker splits or truncates anything. **Resume after distillation (amended: 07):** a resume that starts a fresh top-level journal for a `session_id` whose record `docs/chronicle/sessions/<date>-<sid8>.md` already exists is parked by `next` (C12 step 3), never offered; its content is not merged into the record in phase 2.

**C9 (amended: 02).** Line 4 of the five-line banner:
```
[litopys] distill: <n> pending · run /litopys:distill      (n ≥ 1)
[litopys] distill: nothing pending                          (n = 0)
```
`n` = files matching `.litopys/raw/*.md`, top level only. Lines 1-3 and 5 unchanged; the jq-less fallback unchanged.

**C11 - session record (01 writes, 03 produces the body, recall reads; 07 adds the manifest line).** Path `docs/chronicle/sessions/<YYYY-MM-DD>-<sid8>.md`, date = UTC date of the journal's `started`, sid8 = first 8 chars of the journal's `session_id`.
```
---
litopys: session
version: 1
date: 2026-09-21
session_id: a10ea931-a24f-4942-aa20-743c4eeb9e4a
started: 2026-09-21T11:58:02Z
ended: 2026-09-21T12:58:26Z
branch: main
topics: [litopys, raw-journal, export]
links: [docs/specs/litopys-phase-0-1/plan.md, efedfce]
source: live
tokens: 2355
model: sonnet
---
# <title, one line>

## Decisions
- ...
## Problems
- ...
## Brainstorm
- ...
## Links
- <repo-relative path or sha7> - <why>
```
`started`, `branch`, `session_id` come from the journal frontmatter; `ended` per C13; `topics`/`links` from `--topics a,b` / `--links x,y` (comma-separated, trimmed, default `[]`); `source` from `--source live|backfill` (default `live`, anything else exit 2); `model` from `--model` (default `sonnet`); `tokens` = `tokens_est` (see C14). The body comes from `--body <file>` or `--body -` (stdin): it must begin with one `# ` title line and contain each of `## Decisions`, `## Problems`, `## Brainstorm`, `## Links` exactly once, in that order (else exit 2, nothing written); an empty section holds `- (none)`. The **entire assembled record** (frontmatter + body) is piped through the C16 redactor before it touches disk. Then, in order: one C3 line `- <now> · session · docs/chronicle/sessions/<file> · <title>` through `cmd_append`'s path; `mv` of the journal to `.litopys/raw/done/<sid>.md`; one C14 row to `.litopys/distill.jsonl`; **(07)** the record path and the month-file path appended, repo-relative, one per line, to `<root>/.litopys/distill.paths` (the run manifest `finish` commits from). Prints the record path, exit 0. Existing record: exit 2 `record exists: <path> (use --force)`; with `--force` the record is overwritten and a new C3 line appended. Raw journals never enter git and are never redacted.

**C12 - queue and lock (04 writes `next`, 05 releases in `finish`, 03 calls both; 07 amends steps 2-3 and `finish`'s pathspec).**
- Layout under `<root>/.litopys/raw/`: pending journals at the top level; `done/` (distilled), `skipped/` (never distilled, including `<sid>.resumed.md` parked resumes). Both created on demand (C1 self-ignore already covers them).
- `bin/litopys distill next [--max N]` (default 3): (1) `mkdir "$root/.litopys/distill.lock"`; if it fails and the lock dir is older than 30 minutes (`find "$lock" -maxdepth 0 -mmin +30` prints it), remove it and `mkdir` once more; if it still fails, print `locked` to stderr, exit 3, touch nothing. On success write `<pid> <ts>` into `.litopys/distill.lock/owner`. (2) **(amended: 07)** For every top-level journal decide eligibility first: eligible = last `## ` header is `## closed`, or mtime older than 60 minutes. An ineligible journal is never moved, whatever its content. (3) **(amended: 07)** Over the eligible journals only, oldest first by the frontmatter `started` (file mtime when absent): if the first `## user` block's first content line starts with `/litopys:recall` or `/litopys:distill`, or the journal has no `## user` block at all, `mv` it to `skipped/`; if its record `docs/chronicle/sessions/<date>-<sid8>.md` already exists, `mv` it to `skipped/<sid>.resumed.md` (numeric suffix on collision). Both count as skipped. (4) Print up to N remaining eligible paths, oldest first, one per line, to stdout - built and consumed without `printf %b` or any escape interpretation of a path; print one stderr line `skipped <s> · pending <p> · selected <k>` (`p` = top-level journals left after the moves, `k` ≤ N). (5) If `k = 0`, release the lock before exiting 0. The lock is otherwise released only by `distill finish` (C12/05) or by going stale.
- `bin/litopys distill finish` **(amended: 07)**: reads `.litopys/distill.paths` (deduplicated); missing or empty -> `uncommitted: nothing to commit`; else `git add -- <paths>` and `git commit -m "chore(chronicle): distill <n> session(s) [litopys]" -- <paths>`, `<n>` = distinct `docs/chronicle/sessions/*.md` paths in the manifest. Refusal list per `## Assumptions`. The manifest is removed on `committed` and `nothing to commit`, kept on every refusal. The lock is removed in every case. One stdout line, exit 0.
- Tests pin time with `LITOPYS_NOW` where the CLI stamps, and with `touch -d`/`touch -t` for the mtime rules.

**C14 - distiller agent and skill (03 writes; 01/04/05 provide the CLI it calls).**
`skills/distill/SKILL.md` frontmatter: `name: distill`, `description`, `context: fork`, `agent: distiller`, `allowed-tools: Read, Write, Grep, Glob, Bash`. `agents/distiller.md`: `name: distiller`, `description`, `model: sonnet`, `tools: Read, Write, Grep, Glob, Bash`. Procedure fixed in the agent body:
1. `bash "${CLAUDE_PLUGIN_ROOT}/bin/litopys" distill next` - exit 3 -> return `**Commit:** locked` and stop; empty stdout -> return with `**Distilled:** 0` and `**Commit:** nothing pending` (no `finish` call - C12 step 5 released the lock).
2. Per path: `Read` the journal; ignore `## user` blocks whose first line starts with `/litopys:` and their paired `## assistant`; apply C13; write the C11 body (title + four sections, only what the journal supports, no invention, secrets never copied even when the journal shows them) to `<root>/.litopys/distill-<sid8>.body.md`; run `bash "${CLAUDE_PLUGIN_ROOT}/bin/litopys" distill record --journal <path> --body <bodyfile> --topics <a,b> --links <x,y> --model sonnet`; delete the body file.
3. `bash "${CLAUDE_PLUGIN_ROOT}/bin/litopys" distill finish`.
4. Return shape (the only text that reaches the caller):
```
**Distilled:** <n> session(s)
- docs/chronicle/sessions/<file> - <title>
**Skipped:** <s> (bench/recall journals -> .litopys/raw/skipped/)
**Commit:** <sha7> | uncommitted: <reason> | locked | nothing pending
**Pending:** <p> journal(s) remain
```
`.litopys/distill.jsonl` row, appended by `distill record` (never by the agent):
```
{"ts":"<UTC ISO>","session_id":"<sid>","record":"docs/chronicle/sessions/<file>","journal_bytes":9421,"body_bytes":1800,"tokens_est":2805,"model":"sonnet","source":"live","litopys":"0.2.0"}
```
`tokens_est = (journal_bytes + body_bytes) / 4` (integer division). The agent never writes `memory/learnings/`, `memory/stats/`, `.claude/handoff/`, any `CLAUDE.md`, or anything outside `docs/chronicle/` and `.litopys/`.

**C15 - `bench --delta` (06).** Reads `<root>/.litopys/baseline.jsonl`; baseline = rows 1-5 in file order, latest = the last 5 rows; fewer than 10 rows -> one stderr line, exit 2. No `claude` call. Prints exactly one stdout line and exits 0:
```
delta vs baseline · hits 4/5 -> 5/5 (+1) · refs 7/8 -> 8/8 (+1) · seconds 143 -> 120 (-23) · tokens_in 1187000 -> 900000 (-24%) · tokens_out 6100 -> 5000 (-18%) · cost_usd 0.71 -> 0.60 (-15%)
```
`hits` = count of `hit:true`; `refs` = sum `refs_matched` / sum `refs_expected`; `seconds`, `tokens_in`, `tokens_out`, `cost_usd` = sums over the five rows; a sum with any `null` prints `null` and its delta `n/a`; percentages are integer, relative to the baseline value; `(+0)`/`(0%)` when equal.

**C16 - redactor resolution (01 writes the helper; every git-bound writer uses it).** `redactor()` in `bin/litopys` returns the first existing of `<root>/scripts/redact.sh`, `${CLAUDE_PLUGIN_ROOT}/scripts/redact.sh`, `<dir of bin/litopys>/../scripts/redact.sh`; none -> `cat`. Callers pipe through `bash "$(redactor)"` with the existing `|| printf '%s' "$original"` best-effort fallback. Used by `--note`, `--ref` (C3), the whole C11 record. The plugin's `scripts/redact.sh` = VULYK's, verbatim, header caller names changed. Hooks never redact.

## Integration gate
`for t in tests/*.test.sh; do bash "$t" || exit 1; done && git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null && claude plugin validate .`
(`--strict` is permanently red in this repo - root CLAUDE.md - and is not the gate.) Before each dispatch: `bash scripts/wave-check.sh docs/specs/litopys-phase-2-distill`; after stories are written: `bash scripts/trace-check.sh docs/specs/litopys-phase-2-distill`.

## Tradeoffs
- **Model step in the fork, plumbing in the CLI, vs. the agent doing everything with `Write` + `git`.** Chose a split: `distill next / record / finish` are model-free bash with tests (lock, redaction, pathspec commit are exactly the things that must not depend on a model's discipline), and the agent only reads and writes a body. Rejected the all-agent design: untestable without a model, and a wrong `git add` in an agent's hands sweeps the host's staged work.
- **`append --ref` folded into the tracer vs. its own story.** Chose to fold: the tracer already edits `cmd_append` (the `session` kind) and writes the `redactor()` helper; the ref collapse is four lines and two tests beside code the same worker is holding, and a separate story would need a fifth wave on `bin/litopys`. Rejected a separate story: it fails the neighbour test and serialises the build for nothing.
- **Queue and commit as two stories vs. one.** Chose two: `next` is filesystem logic (sort, mv, mtime), `finish` is git-state logic (detached HEAD, merge/rebase markers, pathspec commit in throwaway repos) - different mental models, different failure modes, and the commit is the one place where a bug damages the host's work, so it gets opus on its own. Same file forces different waves anyway.
- **Byte-estimated tokens vs. no cost row.** Chose the estimate with an honest key name (`tokens_est`) plus one measured number at gate A. Rejected omitting the row: D12 wants a number per session for thresholds, and an estimate proportional to input is enough to rank sessions even if it is not a price.
- **Pathspec commit on the current branch vs. a chronicle branch** (Answer 3, listed under Assumptions for veto): recall reads the working tree; a branch it cannot see defeats the record.
- **Wave 5: one `bin/litopys` fix story vs. one story per finding.** Chose one opus story for findings 1-4: they share `bin/litopys` and `tests/distill.test.sh`, so in one wave they cannot be separate stories, and findings 1, 2, 4 are the same forty lines of `distill_next` (neighbour test); the `finish` manifest is the only distinct piece and is small. Rejected two sequenced waves (next-fixes, then finish): a sixth wave and a second re-orientation on the same file for a diff the size of a helper function.
- **Wave 5: run manifest vs. `git status`-based selection in `finish`.** Chose the manifest written by `record`: `finish` then commits exactly what the plugin wrote, with no guess about which `docs/chronicle/` changes are the host's. Rejected filtering `git status --porcelain -- docs/chronicle` by file shape (`sessions/*.md`, `YYYY-MM.md`): a host edit to the same month file would still be swept.
- **Wave 5: park a resumed-after-distill journal vs. merge it into the record.** Chose parking (`skipped/<sid>.resumed.md`): deterministic, model-free, one `mv`. Rejected a merge: the agent sees only the resume fragment (the first half is already in `done/`), so a faithful merge needs a model reading both, which is phase-5 backfill territory. The loss (resume content not chronicled) is a stated assumption for the owner to veto.

## Descoped
- `tests/lib.sh` extraction (phase-0-1 minor 13): one new suite this phase; extraction when phase 3 adds its suites. See Assumptions.
- `tests/hooks.test.sh` exercising the `CLAUDE_PROJECT_DIR` rung (phase-0-1 minor 12): no Ask names it; not cut.
- `append` idempotence keyed on `(kind, ref, note)` (phase-0-1 UNASKED (b)): no Ask names it; C3's key stays `(ts, kind, ref)`.
- A `/litopys:bench-init` skill (phase-0-1 UNASKED (c)): no Ask names it; the golden-questions copy remains a documented gate step.
- `source: backfill` is accepted by `distill record` (Ask 1 names it) but nothing in this phase produces it - the backfill skill is Roadmap v2 phase 5.
- Review round 1 minor 8 (ordering relies on GNU `date -d` / `stat -c %Y`; on macOS every epoch is 0 and "oldest first" degrades to path order): GNU-only ordering accepted for phase 2 - Windows Git Bash is the primary target, macOS "must not break" holds (it degrades, it does not fail); a portable fallback goes with the `tests/lib.sh` extraction in phase 3.
- Review round 1 minors 6, 7, 9, 10 (minor 10 closes with major 3 - `<n>` counts record paths), 12 (accepted, see Assumptions), 14, 15, 16: not cut this round; carried to the next council round's ledger and to phase 3 unless the council escalates one. Minor 17 (`memory/map/litopys-plugin.md` stale) is the librarian's after merge, not a story.

## Plan deltas
- Review round 1 critical 1: `distill next` must never move or select a journal whose session may still be running - the skip rule applies only to journals that already pass the eligibility rule; a journal without any `## user` block is skipped, not distilled (C12 step 2 amended).
- Review round 1 major 2: the ordering list must carry file paths without passing them through printf escape interpretation (C12, Windows backslash roots).
- Review round 1 major 3: the distill commit must contain only the record files and month files this run wrote - `distill record` appends each path it writes to `.litopys/distill.paths`; `distill finish` stages and commits exactly those paths and `<n>` counts the distinct record paths (C11/C12 amended; replaces the `docs/chronicle` directory pathspec).
- Review round 1 major 4: a journal whose record already exists is parked by `next` into `.litopys/raw/skipped/<sid>.resumed.md` and counted as skipped (C12/C13 amended); the resumed part of an already-distilled session is not chronicled in phase 2.
- Review round 1 major 5: `docs/wiki/chronicle-format.md` must state the C3 amended rules (seven kinds, ref normalisation + redaction, host-then-plugin redactor) and the `## compact` block.
- Build-time deviations recorded (review minors 11, 13): `REVERT_HEAD` joined the refusal list in story 05 (git refuses a partial commit there as with `CHERRY_PICK_HEAD`); `**Commit:** nothing pending` is the fourth value of C14's return shape (story 03); the gate-B result now sits under Gate B.

<!--
The six lines below are the cycle's confirmation artifacts (docs/cycle.md); scripts fill them.
-->
**Approved:** Andrei, 2026-09-21 (one word in the litopys session; gates A and B run by the Queen on the owner's standing authorisation)
**Briefed:**
**Branch:** vulyk/litopys-phase-2-distill
**Checked:**
**Council:**
**Council:** RED round 1, 2026-09-21, at 46ad0f2, pack d1994a26f56c
**Shipped:**
