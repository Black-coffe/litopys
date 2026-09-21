# Scout report: E:/Projects/vulyk/.claude/hooks/ (VULYK hook mechanics)

Scout: drone-scout, 2026-09-21. Reference for litopys hooks - not a design.

## Purpose
VULYK's hooks do three things: (1) guard context budget and auto-dump/restore session "handoffs" (handoff.py, wired to SessionStart/SessionEnd/UserPromptSubmit/Stop/PreCompact), (2) inject small `[VULYK]` context banners at SessionStart (model brief, update check, memory-state brief), (3) side-effect bookkeeping (skill usage counter, anomaly-scan, PreCompact memory snapshot).

## Entry points (settings.json hooks section, E:\Projects\vulyk\.claude\settings.json:4-56)
- `SessionStart` → `session-start-brief.sh`, `top-model-brief.sh`, `vulyk-update-check.sh`, `handoff.sh sessionstart` (no timeouts declared anywhere in settings.json)
- `SessionEnd` → `session-end-learnings.sh`, `handoff.sh sessionend`, `anomaly-scan.sh`
- `UserPromptSubmit` → `handoff.sh prompt`
- `Stop` → `handoff.sh stop`, `anomaly-scan.sh`
- `PostToolUse` (matcher `Skill`) → `skill-usage-counter.sh`
- `PreCompact` → `context-guard.sh`, `handoff.sh precompact`

`handoff.sh` (E:\Projects\vulyk\.claude\hooks\handoff.sh:1-13) is a thin fail-open dispatcher: picks `python3`/`python`/`py` off PATH and `exec`s `handoff.py "$@"`, passing stdin straight through; if no interpreter exists it `exit 0` silently. Windows note (line 5-7): computes its own dir via `pwd -W 2>/dev/null || pwd` because under Git Bash, native `python.exe` cannot open MSYS-style POSIX paths - this is the load-bearing Windows workaround in the whole hook set.

## Key types / contracts

**handoff.py** (E:\Projects\vulyk\.claude\hooks\handoff.py) - the one hook doing real work per event:
- Modes via argv[1]: `stop`, `prompt`, `precompact`, `sessionend`, `sessionstart` (hook modes, read JSON from stdin) plus `dump`, `status`, `measure` (manual/CLI, must NOT block on stdin - see main(), line 951-960: only `HOOK_MODES` read stdin).
- stdin JSON fields used: `session_id`, `transcript_path`, `cwd`, `agent_id` (to skip subagent Stop events, line 732), `reason` (SessionEnd), `source` (SessionStart: `resume`/`fork` short-circuit at line 800; `clear`/`compact` = "deliberate" restore at line 814).
- Output shapes emitted via `emit()` (line 109-113, writes JSON to stdout then `sys.exit(0)`):
  - Stop: `{"systemMessage": "...", "suppressOutput": true}` (line 753) - escalating banner text built by `banner()` (line 717-728).
  - UserPromptSubmit: `{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "..."}}` (line 783) - this is the exact additionalContext JSON shape for that event.
  - SessionStart: same shape, `hookEventName": "SessionStart"` (line 844), content is the restored handoff markdown prefixed with usage instructions.
  - precompact/sessionend dump modes emit a `systemMessage` pointing at the written file (line 794-795), or `emit(None)` (prints nothing) on any failure.
- **Context measurement contract** (line 388-414, `context_tokens()`): reads `transcript_path` JSONL tail, finds the LAST `type=="assistant"` entry where `isSidechain` is falsy, sums `input_tokens + cache_read_input_tokens + cache_creation_input_tokens + output_tokens` from `message.usage`. Subagent/sidechain entries are deliberately excluded - hook payloads carry no token/window info at all, this is derived entirely from transcript content.
- **Window detection** (`detect_window`, line 245-272): config pin → `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_CODE_DISABLE_1M_CONTEXT` env → external `claude-statusbar` cache file (`~/.cache/claude-statusbar/last_stdin.json` or per-session copy) → else unknown, falls back to measured/stock guess in `resolve_window()` (line 275-293).
- **State storage**: `.claude/handoff/state/<session_id>.json` (line 433-434) - per-session anti-spam levels (`stop_level`, `prompt_level`, last known `window`), self-pruned after 7 days (`prune_state`, line 456-466). `.claude/handoff/index.json` (line 95-97) is the single pointer to the freshest handoff dump: `{"path", "cwd", "session_id", "reason", "context_tokens", "ts", "created", "consumed_by_startup"}`. `.claude/handoff/*.md` are the actual dump documents (frontmatter: `handoff`, `session_id`, `created`, `cwd`, `reason`, `context_tokens`, `model`, `enriched`).
- **Windows/encoding**: line 46-50 wraps `sys.stdout.reconfigure(encoding="utf-8")` / stderr in try/except right at module load - explicit UTF-8 forcing for Windows console code pages, guarded because reconfigure isn't always available.
- **CLAUDE_PROJECT_DIR**: `project_root()` (line 81-88) - prefers `os.environ["CLAUDE_PROJECT_DIR"]` if it's a real dir, else falls back to payload `cwd`, else `os.getcwd()`.
- Never crashes: top-level `try/except Exception: sys.exit(0)` around `main()` (line 1004-1011), and `read_stdin_json()` swallows any parse error into `{}` (line 116-126).

## Dependencies
Inbound: Claude Code hook runner invokes each script per settings.json wiring above.
Outbound: `handoff.py` shells out to `git` (subprocess, 5s timeout, line 500-514) and to `scripts/redact.sh` via `subprocess.run(["bash", script], ...)` with a 15s timeout (line 605-611) before writing any transcript-derived text to disk - falls back to an inline regex mirror (`_REDACT_FALLBACK`, line 577-590) if bash/script is unavailable. `session-end-learnings.sh` also calls `scripts/redact.sh` (or `cat` if absent) and optionally shells out to `claude -p --model sonnet` for auto-distillation (opt-in via `VULYK_AUTOLEARN=1`). `anomaly-scan.sh` calls `scripts/telemetry.sh scan` (requires `jq` + a python interpreter, else exits 0 silently).

## redact.sh interface (E:\Projects\vulyk\scripts\redact.sh)
Pure stdin→stdout filter, no model, no tokens, exit code always 0 (line 21, "set -u" not "set -e"). Masks: AWS keys, GitHub tokens (`ghp_`/`gho_`/etc, `github_pat_`), Slack tokens, OpenAI-style `sk-`, Google `AIza`, JWTs, `Bearer <token>` headers, `user:pass@` in URLs, PEM private-key blocks (multi-line, handled by a separate awk pass since sed can't span lines), and generic `key=value`/`key: value` assignments where the key matches a password/secret/api-key/token keyword list. Degrades to `cat` (passthrough, unredacted) if `sed`/`awk` are missing or the sed dialect rejects the extended-regex script (BSD sed dialect check at line 43-44) - documented, deliberate "never eat the data" tradeoff.

## journal.sh CLI shape (E:\Projects\vulyk\scripts\journal.sh)
```
scripts/journal.sh <spec-dir> <stage> "<what happened>" "<what next>"
```
Appends one line to `<spec-dir>/journal.md` (creates the file with a `# Journal: <name>` header if absent) AND echoes the same line to stdout, so callers relay stdout rather than re-deriving text. Line format:
```
- 2026-09-21T12:34:56Z · <stage> · <what happened> · next: <what next>
```
(UTC ISO-8601 timestamp, `date -u +%Y-%m-%dT%H:%M:%SZ`, then ` · ` separators.) `<stage>` is caller-defined free text, not validated. Exit status is always 0 - appending a record is never a gate. For a new `append` command mirroring this, the load-bearing pattern is: create-with-header-if-missing, append one line, print the same line to stdout, always exit 0.

## Gotchas
- `handoff.sh` Windows path fix (`pwd -W`) is the single most important portability trick here - needed because native `python.exe` under Git Bash chokes on `/c/...`-style MSYS paths. Directly relevant if litopys hooks also shell out from bash to a Windows-native interpreter.
- `handoff.py` explicitly separates "hook modes" (read stdin) from "manual modes" (`dump`, `status`, `measure` - must NOT read stdin, since a terminal invocation would block on an open pipe forever). This was a real bug ("review finding 16", line 953-956) - copy the pattern for any new CLI-invocable hook script.
- All hook scripts are fail-open by convention: every one either checks `command -v <tool>` before using jq/python/curl or wraps subprocess calls in try/except, and exits 0 on any failure without blocking the session. `redact.sh` and `handoff.py`'s redact fallback both explicitly choose "unredacted passthrough" over "silently eat the content" as the failure mode.
- `vulyk-update-check.sh` caches its GitHub API result (`.claude/.vulyk-update-cache`, default 24h interval) - pattern worth reusing for any network-touching SessionStart hook.
- `context-guard.sh` (PreCompact) writes timestamped snapshot dirs under `memory/snapshots/` on every compaction with no pruning visible - potential unbounded growth if copied verbatim.
- No `timeout` fields are declared for any hook in settings.json (all rely on internal fail-open behavior / short subprocess timeouts inside the scripts: 5s git, 15s redact.sh, 4s curl).
- `session-end-learnings.sh`'s auto-distillation path (`VULYK_AUTOLEARN=1`) shells out to `claude -p --model sonnet` reading up to 200KB of transcript tail - a SessionEnd hook invoking the CLI itself. Official docs (verified 2026-09-21): SessionEnd hooks share a 1.5 s budget, raised by `timeout` to at most 60 s - this path cannot complete on a real transcript.

## Not covered
`scripts/telemetry.sh` and `scripts/top-model.sh` internals - separate scripts, not hooks.
