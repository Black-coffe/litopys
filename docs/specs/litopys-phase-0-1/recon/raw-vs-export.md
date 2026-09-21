# Report: raw journal vs `/export` on one real VULYK session

## Header

- Session id: `a10ea931-a24f-4942-aa20-743c4eeb9e4a`, project `E:/Projects/vulyk`, date 2026-09-21, run under `claude --plugin-dir E:/Projects/litopys` (five `claude -p -r` turns, then one interactive resume for `/export` + `/exit`).
- Token count as Claude Code reported it (owner-supplied, `--output-format json` usage per turn): turn 1 129,774 · turn 2 160,046 · turn 3 570,413 (7 model calls, tool loop) · turn 4 218,625 · turn 5 128,088; total well past the 100k bar; cost USD 2.38.
- Raw journal: `E:/Projects/vulyk/.litopys/raw/a10ea931-a24f-4942-aa20-743c4eeb9e4a.md` — 9,421 bytes, 122 lines.
- Export: `E:/Projects/vulyk/.litopys/export-a10ea931.md` — 9,472 bytes, 184 lines.
- Block/turn counts: journal has 5 `## user` blocks, 5 `## assistant` blocks, 6 `## closed` blocks (5 `· other`, 1 `· prompt_input_exit` — one per `-p -r` process exit plus the final interactive exit). Export has 5 user turns (`❯` prompts) and 6 assistant (`●`) blocks — turn 1 alone splits into two `●` blocks (a preamble, then the answer); turns 2–5 are one `●` block each.
- A third file, `E:/Projects/vulyk/.litopys/export-a10ea931.md.pty.log`, sits alongside the export as a raw terminal capture (a byte-for-byte ANSI recording of the interactive resume session). It is not the journal and not `/export`'s output, so it is not one of the two files this ask compares; observations sourced from it are collected separately in `## Outside the comparison (pty log)` below.

## Losses

1. **Tool calls and their results.** Export lines 12, 32, 70, 99 show `Read 1 file (ctrl+o to expand)`, `Read 2 files (ctrl+o to expand)`, `Searched for 2 patterns, read 1 file, ran 2 shell commands (ctrl+o to expand)`, `Read 1 file (ctrl+o to expand)`. The journal has zero occurrences of any tool marker (`grep -c 'Read\|Searched\|ran 2 shell' raw/a10ea931….md` → 0) — nothing in C8's format (plan.md:99-117) records tool use at all, only `user`/`assistant`/`closed`.
2. **Intermediate assistant turns before the final one of a Stop.** Export's first turn has two `●` blocks: "I'll read the project's CLAUDE.md file directly." (a preamble, before the tool call) and then the actual Five Laws answer. Journal block at line 13 (`## assistant · 2026-09-21T12:46:09Z`) starts directly with "The Five Laws (CLAUDE.md:13-17):" — the preamble sentence is gone. This matches the contract's own semantics: `## assistant` stores `<last_assistant_message verbatim>` (plan.md:114), so anything before the final message of a turn is dropped by design.
3. **Session/environment banner shown at the top of the export itself.** `export-a10ea931.md` lines 1-3 carry the startup banner verbatim — `Claude Code v2.1.278` (line 1), `Sonnet 5 · Claude Max` (line 2), `E:\Projects\vulyk` (line 3, the cwd). None of this appears anywhere in the journal's YAML frontmatter (only `session_id`, `started`, `cwd`, `branch` are captured, and `cwd` is stored as a plain value, not this banner form) or body — `grep -c 'Claude Code v2.1.278\|Sonnet 5 · Claude Max' raw/a10ea931….md` → 0.
4. **Compaction summaries — checked, not applicable to this session.** The story's inputs flag the turn 4→5 token drop (218,625 → 128,088) as an auto-compaction candidate. Neither of the two named files shows a compaction marker: `grep -i 'compact' raw/a10ea931….md export-a10ea931.md` returns nothing in either. This item is inconclusive from journal-vs-export alone, not a confirmed journal-specific loss.
5. **Subagent output — checked, not present in this session.** No `Task(` invocation appears in either the journal or the export (`grep -c 'Task(' raw/a10ea931….md export-a10ea931.md` → 0 in both), so this session gives no example either way; flagged as a candidate phase 2 still needs to test on a session that actually delegates.

## Kept

1. **User input verbatim.** Journal line 10 (`## user · 2026-09-21T12:46:04Z`) reproduces the turn 1 prompt exactly as it appears at export's first `❯` block.
2. **The final assistant answer of each turn.** Journal's turn 4 assistant block (lines 64-100, the `telemetry.sh` bug + diff) matches the export's `●` answer text for that turn word-for-word, including the unified diff.
3. **Session identity metadata.** Journal frontmatter (`session_id`, `cwd: E:\Projects\vulyk`, `branch: main`) matches the export's own banner (`export-a10ea931.md` line 3, `E:\Projects\vulyk`) and prompt path for the same session.
4. **Turn boundaries.** The 5 `## closed · … · other` lines line up 1:1 with the 5 separate `claude -p -r` invocations the story's Inputs describe; the final `prompt_input_exit` line marks the interactive resume's end, matching the last user turn recorded in the export.

## Outside the comparison (pty log)

These are terminal-capture facts sourced from `export-a10ea931.md.pty.log` — a byte-for-byte ANSI recording of the live terminal, not the journal and not `/export`'s output. The ask names only those two files for comparison, so nothing here counts as a journal-vs-export loss; phase 2 may or may not decide these are worth capturing separately.

1. **Slash-command expansions and their output.** The pty log's line 1 (a single long ANSI-escaped capture line) contains the literal command text `❯ /export E:/Projects/vulyk/.litopys/export-a10ea931.md`, its confirmation `⎿  Conversation exported to: …`, and the following `❯ /exit`. `grep -c '/export\|/exit' raw/a10ea931….md export-a10ea931.md` → 0 in both — neither of the two named files contains this command text or confirmation anywhere; only the pty log records that a slash command ran at all.
2. **Live session/environment readouts.** Pty log line 1 also carries the resume hint (literal marker `claude --resume a10ea931-a24f-4942-aa20-743c4eeb9e4a`, repeated standalone at pty log line 3), the effort indicator (`◐ medium · /effort`), the permission-mode banner (`⏵⏵ bypass permissions on`), and a live context-usage readout (`Sonnet 5(128.1k/1.0M)`). None of these live readouts appear in the export file itself (distinct from the static startup banner in Loss 3, which the export does carry).

## Verdict

For this session, the journal alone is enough to reconstruct *what was decided* (each turn's final assistant message carries the brainstorm options, the chosen one and its reasoning, or the bug + diff verbatim) but not *how it was reached* — everything about tool use and any assistant turn before a Stop's last message is invisible. Because this was a run of single-shot Q&A turns, the "decision" text happened to land entirely in the last assistant message each time; a session where the interesting brainstorming happens across several tool-mediated steps before a final answer would lose more (per loss #2, "как брейнштормили" is exactly what `last_assistant_message`-only capture drops first). The slash-command/session-control layer (`/export`, `/exit`, `/effort`, permission mode) is invisible too, but that observation comes from the pty log, not from comparing the journal to the export — see `## Outside the comparison (pty log)` above. Phase 2 needs, at minimum:

1. A compact tool-call/tool-result summary per turn (name + one-line result), sourced from `PreToolUse`/`PostToolUse` payloads.
2. All assistant messages of a turn, not just the last one before Stop (or at least a flag marking that intermediate messages existed and were dropped).
3. If session-control actions (`/export`, `/exit`, `/effort` and similar) are wanted in the journal too, a source narrower than a raw pty capture — e.g. `UserPromptSubmit`/`PostToolUse` payloads — since this ask's two files carry none of that text today.
