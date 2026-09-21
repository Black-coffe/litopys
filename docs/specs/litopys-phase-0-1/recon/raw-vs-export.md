# Report: raw journal vs `/export` on one real VULYK session

## Header

- Session id: `a10ea931-a24f-4942-aa20-743c4eeb9e4a`, project `E:/Projects/vulyk`, date 2026-09-21, run under `claude --plugin-dir E:/Projects/litopys` (five `claude -p -r` turns, then one interactive resume for `/export` + `/exit`).
- Token count as Claude Code reported it (owner-supplied, `--output-format json` usage per turn): turn 1 129,774 · turn 2 160,046 · turn 3 570,413 (7 model calls, tool loop) · turn 4 218,625 · turn 5 128,088; total well past the 100k bar; cost USD 2.38.
- Raw journal: `E:/Projects/vulyk/.litopys/raw/a10ea931-a24f-4942-aa20-743c4eeb9e4a.md` — 9,421 bytes, 122 lines.
- Export: `E:/Projects/vulyk/.litopys/export-a10ea931.md` — 9,472 bytes, 184 lines.
- Block/turn counts: journal has 5 `## user` blocks, 5 `## assistant` blocks, 6 `## closed` blocks (5 `· other`, 1 `· prompt_input_exit` — one per `-p -r` process exit plus the final interactive exit). Export has 5 user turns (`❯` prompts) and 6 assistant (`●`) blocks — turn 1 alone splits into two `●` blocks (a preamble, then the answer); turns 2–5 are one `●` block each.

## Losses

1. **Tool calls and their results.** Export lines 12, 32, 70, 99 show `Read 1 file (ctrl+o to expand)`, `Read 2 files (ctrl+o to expand)`, `Searched for 2 patterns, read 1 file, ran 2 shell commands (ctrl+o to expand)`, `Read 1 file (ctrl+o to expand)`. The journal has zero occurrences of any tool marker (`grep -c 'Read\|Searched\|ran 2 shell' raw/a10ea931….md` → 0) — nothing in C8's format (plan.md:99-117) records tool use at all, only `user`/`assistant`/`closed`.
2. **Intermediate assistant turns before the final one of a Stop.** Export's first turn has two `●` blocks: "I'll read the project's CLAUDE.md file directly." (a preamble, before the tool call) and then the actual Five Laws answer. Journal block at line 13 (`## assistant · 2026-09-21T12:46:09Z`) starts directly with "The Five Laws (CLAUDE.md:13-17):" — the preamble sentence is gone. This matches the contract's own semantics: `## assistant` stores `<last_assistant_message verbatim>` (plan.md:114), so anything before the final message of a turn is dropped by design.
3. **Slash-command expansions and their output.** Export's pty capture shows the literal command `❯ /export E:/Projects/vulyk/.litopys/export-a10ea931.md` and its result `⎿ Conversation exported to: …`, followed by `❯ /exit`. Journal's only trace of this whole interactive segment is `## closed · 2026-09-21T12:58:26Z · prompt_input_exit` (line 122) — no command text, no confirmation line, no indication a slash command ran at all.
4. **Session/environment metadata shown in the terminal.** Export's pty log carries the startup banner (`Claude Code v2.1.278 · Sonnet 5 · Claude Max`), the resume hint (`claude --resume a10ea931-a24f-4942-aa20-743c4eeb9e4a`), the effort indicator (`◐ medium · /effort`), the permission mode (`⏵⏵ bypass permissions on`), and a context-usage readout (`Sonnet 5(128.1k/1.0M)`). None of this appears anywhere in the journal's YAML frontmatter (only `session_id`, `started`, `cwd`, `branch` are captured) or body.
5. **Compaction summaries — checked, not applicable to this session.** The story's inputs flag the turn 4→5 token drop (218,625 → 128,088) as an auto-compaction candidate. Neither file shows a compaction marker: `grep -i 'compact' export-a10ea931.md export-a10ea931.md.pty.log` returns nothing, and the resumed-session context readout (`128.1k/1.0M`) reflects the fresh `/resume` context, not a mid-turn compaction event. This item is inconclusive from journal-vs-export alone, not a confirmed journal-specific loss.
6. **Subagent output — checked, not present in this session.** No `Task(` invocation appears in the export or its pty log, so this session gives no example either way; flagged as a candidate phase 2 still needs to test on a session that actually delegates.

## Kept

1. **User input verbatim.** Journal line 10 (`## user · 2026-09-21T12:46:04Z`) reproduces the turn 1 prompt exactly as it appears at export's first `❯` block.
2. **The final assistant answer of each turn.** Journal's turn 4 assistant block (lines 64-100, the `telemetry.sh` bug + diff) matches the export's `●` answer text for that turn word-for-word, including the unified diff.
3. **Session identity metadata.** Journal frontmatter (`session_id`, `cwd: E:\Projects\vulyk`, `branch: main`) matches the export's resume hint and prompt path for the same session.
4. **Turn boundaries.** The 5 `## closed · … · other` lines line up 1:1 with the 5 separate `claude -p -r` invocations the story's Inputs describe; the final `prompt_input_exit` line marks the interactive resume's end, matching export's `/exit`.

## Verdict

For this session, the journal alone is enough to reconstruct *what was decided* (each turn's final assistant message carries the brainstorm options, the chosen one and its reasoning, or the bug + diff verbatim) but not *how it was reached or wrapped* — everything about tool use, any assistant turn before a Stop's last message, and the slash-command/session-control layer is invisible. Because this was a run of single-shot Q&A turns, the "decision" text happened to land entirely in the last assistant message each time; a session where the interesting brainstorming happens across several tool-mediated steps before a final answer would lose more (per loss #2, "как брейнштормили" is exactly what `last_assistant_message`-only capture drops first). Phase 2 needs, at minimum:

1. A compact tool-call/tool-result summary per turn (name + one-line result), sourced from `PreToolUse`/`PostToolUse` payloads.
2. All assistant messages of a turn, not just the last one before Stop (or at least a flag marking that intermediate messages existed and were dropped).
3. Slash-command text and its confirmation captured via `UserPromptSubmit`/`PostToolUse`, so `/export`, `/exit`, `/effort` and similar session-control actions leave a trace.
