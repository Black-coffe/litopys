# Scout report: VULYK host mechanics (redact.sh, journal.sh, raw journal format, phase-0-1 verdict, hooks) for litopys phase 2 (distill)

## Purpose
Recon for the distillation phase: what redaction/journal conventions the host (VULYK) already has, what a real >=100k raw session journal looks like on disk, what phase-0-1 found missing vs `/export`, and which VULYK hooks already do learnings/handoff/anomaly work that phase 2's distiller must not collide with.

## Entry points
- `E:/Projects/vulyk/scripts/redact.sh:1-59` - stdin->stdout secret masker, model for the plugin's fallback `scripts/redact.sh`.
- `E:/Projects/vulyk/scripts/journal.sh:1-33` - one-line-per-state-change appender, model for the plugin's journal mirror.
- `E:/Projects/vulyk/.litopys/raw/a10ea931-a24f-4942-aa20-743c4eeb9e4a.md` - the real >=100k-token raw session journal (122 lines, 9,421 bytes).
- `E:/Projects/litopys/docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` - prior recon comparing this journal to `/export`.
- `E:/Projects/vulyk/.claude/hooks/session-end-learnings.sh`, `anomaly-scan.sh`, `handoff.sh`+`handoff.py` - VULYK's own SessionEnd/Stop hooks, wired in `E:/Projects/vulyk/.claude/settings.json`.

## Key types / contracts

**redact.sh**
- Usage: `some-writer | scripts/redact.sh > file` - pure stdin->stdout filter, no args, no model call (line 4). Exit status always 0 (lines 19, 58) - "never blocks".
- Degrades to `cat` (unredacted passthrough) if `sed` or `awk` is missing or the sed dialect rejects the expression array (lines 42-47, dry-run `printf '' | sed "${SED_ARGS[@]}"`).
- Two-pass: awk strips multi-line PEM private-key blocks (lines 51-56, `-----BEGIN ... PRIVATE KEY-----` to `-----END ...`, replaced by `[VULYK:REDACTED]`), then `sed "${SED_ARGS[@]}"` for single-line patterns.
- Patterns (`MASK='[VULYK:REDACTED]'`, lines 28-40): AWS `AKIA[0-9A-Z]{16}` (29), STS `ASIA[0-9A-Z]{16}` (30), GitHub `gh[pousr]_[A-Za-z0-9]{20,}` (31), `github_pat_[A-Za-z0-9_]{22,}` (32), Slack `xox[baprs]-[A-Za-z0-9-]{10,}` (33), `sk-[A-Za-z0-9_-]{20,}` (34), Google `AIza[0-9A-Za-z_-]{35}` (35), JWT three-segment `eyJ...` (36), `Bearer <token>` 16+ chars (37), URL `://user:pass@` password segment (38), generic `KEY=VALUE`/`KEY: VALUE` whose key contains password/secret/api_key/access_key/auth_token/client_secret/private_key in three case variants (26, 39) and whose value is 6+ non-quote/non-space chars.
- 59 lines, POSIX `sed -E` + `awk` only, no VULYK-specific logic, no sourcing - **copy verbatim** into the plugin's `scripts/redact.sh`; only the header comment's caller names change. Maintenance note (lines 13-14): `handoff.py` keeps a duplicate minimal Python subset - a second implementation to keep in sync.

**journal.sh**
- `scripts/journal.sh <spec-dir> <stage> "<what happened>" "<what next>"` (lines 5-6); creates `<spec-dir>/journal.md` with a `# Journal: <basename>` header if missing (24-28).
- Line format (30): `- <UTC ISO8601> · <stage> · <what happened> · next: <what next>`. **No idempotence key** - every call appends; echoes the same line to stdout (32); exit 0 always (33), usage error only warns (19-22).

**Raw journal format**, from `a10ea931-....md`:
- Frontmatter keys (lines 1-8), same six in all 17 raw files: `litopys: raw`, `version: 1`, `session_id`, `started` (UTC ISO8601), `cwd`, `branch`.
- Block headers: `## user · <ts>`, `## assistant · <ts>`, `## closed · <ts> · <reason>`. This session: 5 user, 5 assistant, 6 closed (5 `· other`, 1 `· prompt_input_exit`).
- A mid-session `## closed` is a bare header line followed by a blank line and the next `## user` (e.g. lines 22-23). No truncation markers in prompts or assistant blocks; no secret-shaped strings present.
- Other raw files: 17 in total. `ac90b6ae-...` first user line `Say exactly: litopys hook smoke test. Nothing else.` (smoke test). The other 15 are bench-run journals and **all start their first `## user` line with the literal `/litopys:recall <question>`**, no leading whitespace, one line (five distinct questions, 3 runs each). Sizes (Queen, `ls -l`): bench journals 1.5-2.5 KB each; a10ea931 9,421 bytes.

**Phase-0-1 verdict**, verbatim from `recon/raw-vs-export.md`:
- `## Losses` titles: 1 "**Tool calls and their results.**" 2 "**Intermediate assistant turns before the final one of a Stop.**" 3 "**Session/environment banner shown at the top of the export itself.**" 4 "**Compaction summaries - checked, not applicable to this session.**" 5 "**Subagent output - checked, not present in this session.**"
- `## Verdict` list: 1 "A compact tool-call/tool-result summary per turn (name + one-line result), sourced from `PreToolUse`/`PostToolUse` payloads." 2 "All assistant messages of a turn, not just the last one before Stop (or at least a flag marking that intermediate messages existed and were dropped)." 3 "If session-control actions (`/export`, `/exit`, `/effort` and similar) are wanted in the journal too, a source narrower than a raw pty capture - e.g. `UserPromptSubmit`/`PostToolUse` payloads."

**VULYK's own hooks** (`E:/Projects/vulyk/.claude/settings.json`):
- `SessionEnd` (settings.json 15-20): `session-end-learnings.sh`, then `handoff.sh sessionend`, then `anomaly-scan.sh`. `Stop` (31-35): `handoff.sh stop`, `anomaly-scan.sh`. `SessionStart` (11): `handoff.sh sessionstart`. `UserPromptSubmit` (27): `handoff.sh prompt`. `PreCompact` (51): `handoff.sh precompact`.
- `session-end-learnings.sh`: writes a stub `memory/learnings/<TS>.md` (committed) by default; with `VULYK_AUTOLEARN=1` pipes the last 200KB of the transcript through `claude -p --model sonnet` and writes through `redact.sh` (falls back to `cat`, line 13). **Phase 4 removes this hook; phase 2's distiller must not also fire on the same transcript into `memory/learnings/`, and must not treat `memory/learnings/` as its own.**
- `anomaly-scan.sh`: Stop + SessionEnd, fail-open/silent, runs `scripts/telemetry.sh scan --transcript <path> [--final]`, writes `memory/stats/anomalies.jsonl` - **untouchable by the distiller**.
- `handoff.sh`/`handoff.py`: fail-open Python-interpreter finder execing `handoff.py`, maintains `.claude/handoff/` resume state - **untouchable**. `handoff.py` body not read.

## Dependencies
- `redact.sh` inbound: `session-end-learnings.sh` (line 13) and `handoff.py` (per header comment). `journal.sh` inbound: `cycle.sh`, `/vulyk-plan`, `/vulyk-ship`, hooks (per header). None of VULYK's hooks write to `.litopys/`; only the litopys plugin does.

## Gotchas
- `redact.sh` keyword match is a substring match on the key name, not word-boundary ("intentionally loud rather than clever", lines 10-11).
- `redact.sh` silently degrades to `cat` when `sed`/`awk` are missing - a copied fallback inherits the silent-passthrough tradeoff; the plugin's docs should say so.
- `journal.sh` has no idempotence key; do not design the plugin's append around an assumed upstream dedupe.
- The raw `## assistant` block is only the *last* assistant message before a Stop (report Losses 2 / Kept 2) - by the format's design (plan.md C8).
- `session-end-learnings.sh` auto-distillation (`VULYK_AUTOLEARN=1`) already exists in the host: phase 2's output path must be disjoint from `memory/learnings/`.

## Answer
1. `redact.sh` is a 59-line stdin->stdout sed+awk filter, exit 0 always, degrades to `cat`; masks AWS/GitHub/Slack/OpenAI/Google keys, JWTs, Bearer tokens, URL credentials, PEM blocks and generic `key=secret` assignments; zero VULYK dependencies - copy verbatim into the plugin.
2. `journal.sh` appends `- <ts> · <stage> · <what> · next: <next>` unconditionally, no dedupe.
3. The real raw journal has six frontmatter keys, alternating user/assistant blocks and bare `## closed` markers that can sit mid-file; 15 of 17 journals on disk are bench runs whose first user line is `/litopys:recall <question>`.
4. Losses and Verdict quoted above.
5. VULYK runs three hooks phase 2 must stay clear of: `session-end-learnings.sh` (`memory/learnings/`), `anomaly-scan.sh` (`memory/stats/anomalies.jsonl`), `handoff.*` (`.claude/handoff/`); all fail-open - the distiller should follow the same convention with its own disjoint output path.

last-verified: 2026-09-21 (drone-scout, sonnet; written to disk by the Queen - scouts carry no Write tool; sizes added by the Queen)
