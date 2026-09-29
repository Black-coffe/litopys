#!/usr/bin/env bash
# The raw journal hooks - wiring, on-disk journal, banner, fail-open (C1, C7, C8, C9).
#
#   Usage: bash tests/hooks.test.sh             # from the litopys repo root
#
# Same style as append.test.sh: throwaway dirs under mktemp -d, assertions about what landed
# on disk or what the hook printed, non-zero exit on the first wrong answer. No model, no
# network: every hook is fed a payload on stdin exactly as Claude Code would.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$SRC/hooks/raw-journal.sh"
START="$SRC/hooks/session-start.sh"
WIRING="$SRC/hooks/hooks.json"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

FAILED="$T/failures"
: > "$FAILED"
bad() { echo "::error::$1"; echo "$1" >> "$FAILED"; }

expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then echo "  ok    $label"
  else bad "$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}
refute() { # refute <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    bad "$label - did NOT expect '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'
  else echo "  ok    $label"; fi
}
eq() { # eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok    $1"
  else bad "$1 - expected '$2', got '$3'"; fi
}
no_file() { # no_file <label> <path>
  if [ -e "$2" ]; then bad "$1 - $2 exists and should not"; else echo "  ok    $1"; fi
}

if ! command -v jq > /dev/null 2>&1; then
  echo "hooks.test.sh: jq not found - this suite feeds JSON payloads and needs it"; exit 1
fi
unset CLAUDE_PROJECT_DIR 2>/dev/null || true
NOW="2026-09-21T12:34:56Z"

# --- C7: the wiring ------------------------------------------------------------------------
jq -e . "$WIRING" > /dev/null 2>&1
eq "hooks.json is valid JSON" "0" "$?"
for ev in UserPromptSubmit Stop SessionEnd SessionStart PreCompact; do
  cmd="$(jq -r --arg e "$ev" '.hooks[$e][0].hooks[0].command // ""' "$WIRING")"
  printf '%s' "$cmd" | expect "$ev command uses CLAUDE_PLUGIN_ROOT" '${CLAUDE_PLUGIN_ROOT}/hooks/'
  eq "$ev hook is type command" "command" "$(jq -r --arg e "$ev" '.hooks[$e][0].hooks[0].type' "$WIRING")"
done
eq "hooks.json has exactly five event keys" "5" "$(jq -r '.hooks | keys | length' "$WIRING")"
jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$WIRING" | expect "prompt mode wired" 'raw-journal.sh" prompt'
jq -r '.hooks.Stop[0].hooks[0].command' "$WIRING" | expect "stop mode wired" 'raw-journal.sh" stop'
jq -r '.hooks.SessionEnd[0].hooks[0].command' "$WIRING" | expect "end mode wired" 'raw-journal.sh" end'
jq -r '.hooks.SessionStart[0].hooks[0].command' "$WIRING" | expect "banner wired" 'session-start.sh"'
jq -r '.hooks.PreCompact[0].hooks[0].command' "$WIRING" | expect "compact mode wired" 'raw-journal.sh" compact'
eq "SessionEnd declares no timeout" "false" "$(jq -r '.hooks.SessionEnd[0].hooks[0] | has("timeout")' "$WIRING")"
eq "UserPromptSubmit timeout is 10" "10" "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].timeout' "$WIRING")"
eq "Stop timeout is 10" "10" "$(jq -r '.hooks.Stop[0].hooks[0].timeout' "$WIRING")"
eq "SessionStart timeout is 10" "10" "$(jq -r '.hooks.SessionStart[0].hooks[0].timeout' "$WIRING")"
eq "PreCompact timeout is 10" "10" "$(jq -r '.hooks.PreCompact[0].hooks[0].timeout' "$WIRING")"

# --- C8: prompt creates the journal from the payload's cwd ---------------------------------
P="$T/proj"
mkdir -p "$P"
( cd "$P" && git init -q -b feat/journal . && git config user.email t@t && git config user.name "T" )
J="$P/.litopys/raw/s1.md"

printf '{"session_id":"s1","cwd":"%s","user_input":"hi there"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt > "$T/out1" 2> "$T/err1"
eq "prompt exits 0" "0" "$?"
eq "prompt prints nothing to stdout" "" "$(cat "$T/out1")"
cat "$J" | expect "frontmatter opens" "litopys: raw"
cat "$J" | expect "version 1" "version: 1"
cat "$J" | expect "session_id in frontmatter" "session_id: s1"
cat "$J" | expect "started is the ts" "started: $NOW"
cat "$J" | expect "cwd from the payload" "cwd: $P"
cat "$J" | expect "branch from git -C cwd" "branch: feat/journal"
cat "$J" | expect "user block" "## user · $NOW"
cat "$J" | expect "user text verbatim" "hi there"
cat "$P/.litopys/.gitignore" | expect ".litopys ignores itself" "*"

# --- .prompt is read when .user_input is absent --------------------------------------------
printf '{"session_id":"s1","cwd":"%s","prompt":"second turn"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt
cat "$J" | expect "reads .prompt as the fallback field" "second turn"

# --- C8: stop appends the assistant block ---------------------------------------------------
printf '{"session_id":"s1","cwd":"%s","last_assistant_message":"an answer"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" stop
eq "stop exits 0" "0" "$?"
cat "$J" | expect "assistant block" "## assistant · $NOW"
cat "$J" | expect "assistant text verbatim" "an answer"

# --- a subagent Stop (non-empty agent_id) writes nothing ------------------------------------
before="$(wc -c < "$J")"
printf '{"session_id":"s1","cwd":"%s","agent_id":"sub-7","last_assistant_message":"forked turn"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" stop
eq "subagent stop exits 0" "0" "$?"
eq "subagent stop writes nothing" "$before" "$(wc -c < "$J")"
cat "$J" | refute "forked turn never lands in the journal" "forked turn"

# --- a second session id gets its own file ---------------------------------------------------
printf '{"session_id":"s2","cwd":"%s","user_input":"other session"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt
cat "$P/.litopys/raw/s2.md" | expect "second session has its own journal" "session_id: s2"
cat "$J" | refute "second session did not touch the first" "other session"

# --- C8: end appends exactly one closing line, under a second --------------------------------
t0="$(date +%s)"
printf '{"session_id":"s1","cwd":"%s","reason":"clear"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" end
rc=$?
t1="$(date +%s)"
eq "end exits 0" "0" "$rc"
elapsed=$((t1 - t0))
if [ "$elapsed" -le 1 ]; then echo "  ok    end finishes within a second (${elapsed}s)"
else bad "end took ${elapsed}s - SessionEnd's budget is 1.5s"; fi
cat "$J" | expect "closed line with reason" "## closed · $NOW · clear"
eq "exactly one closed line" "1" "$(grep -c '^## closed · ' "$J")"
eq "end added nothing but the closed block" "1" "$(tail -n 1 "$J" | grep -c '^## closed · ')"
endbody="$(awk '/^journal_end\(\) \{/,/^\}/' "$RAW")"
eq "the end path contains exactly one write" "1" "$(printf '%s\n' "$endbody" | grep -c '>>')"

# --- end with no journal: exit 0, create nothing ---------------------------------------------
printf '{"session_id":"never-was","cwd":"%s","reason":"other"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" end
eq "end without a journal exits 0" "0" "$?"
no_file "end without a journal creates nothing" "$P/.litopys/raw/never-was.md"

# --- C13: resume after close - a further prompt appends past '## closed' ---------------------
printf '{"session_id":"s1","cwd":"%s","user_input":"resumed after close"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt
order="$(grep -n '^## closed · \|^## user · ' "$J" | tail -2)"
first="$(printf '%s\n' "$order" | head -1)"
second="$(printf '%s\n' "$order" | tail -1)"
printf '%s' "$first" | expect "closed comes before the resumed user block" "## closed"
printf '%s' "$second" | expect "a new user block follows the close" "## user"
cat "$J" | expect "resumed prompt text lands in the journal" "resumed after close"

# --- C7/C8/C13: PreCompact appends a compact marker with the trigger -------------------------
printf '{"session_id":"s2","cwd":"%s","compaction_trigger":"auto"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" compact
eq "compact exits 0" "0" "$?"
J2="$P/.litopys/raw/s2.md"
cat "$J2" | expect "compact marker with trigger" "## compact · $NOW · auto"

printf '{"session_id":"s2","cwd":"%s"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" compact
cat "$J2" | expect "compact with no trigger field falls back to a dash" "## compact · $NOW · -"

printf '{"session_id":"compact-never-was","cwd":"%s","compaction_trigger":"manual"}' "$P" \
  | LITOPYS_NOW="$NOW" bash "$RAW" compact
eq "compact without a journal exits 0" "0" "$?"
no_file "compact without a journal creates nothing" "$P/.litopys/raw/compact-never-was.md"

# --- correction-evidence C1: harness text is a notice, not the owner ------------------------------
say() { # say <sid> <prompt text> - feed one UserPromptSubmit payload built by jq (newlines survive)
  jq -n --arg s "$1" --arg c "$P" --arg p "$2" '{session_id: $s, cwd: $c, prompt: $p}' \
    | LITOPYS_NOW="$NOW" bash "$RAW" prompt
}
NL=$'\n'
say n1 "<task-notification>${NL}<task-id>a1</task-id>${NL}<result>the subagent's report</result>${NL}</task-notification>"
N1="$P/.litopys/raw/n1.md"
cat "$N1" | expect "a notification-only prompt -> one notice block of its kind" "## notice · $NOW · task-notification"
cat "$N1" | expect "the notice keeps the segment verbatim" "<result>the subagent's report</result>"
cat "$N1" | refute "a notification-only prompt writes no user block" "## user"

say n2 "first human part <pasted_content id=\"x\">a pasted log${NL}line 2</pasted_content> second human part"
N2="$P/.litopys/raw/n2.md"
eq "neighbour: the human parts land in one user block, first" "## user · $NOW" "$(grep '^## ' "$N2" | head -1)"
eq "neighbour: then the pasted segment as its own notice" "## notice · $NOW · pasted" "$(grep '^## ' "$N2" | sed -n 2p)"
sed -n '/^## user/,/^## notice/p' "$N2" | expect "both human parts are in the user block" "first human part  second human part"
sed -n '/^## user/,/^## notice/p' "$N2" | refute "the pasted text is not in the user block" "a pasted log"

say n3 "look <system-reminder>be brief</system-reminder> and <cross-session-message from=\"w\">hi</cross-session-message> done"
N3="$P/.litopys/raw/n3.md"
cat "$N3" | expect "a system-reminder is its own notice kind" "## notice · $NOW · system-reminder"
cat "$N3" | expect "a cross-session message is its own notice kind" "## notice · $NOW · cross-session"
say n4 "text then <system-reminder>never closed${NL}still the reminder"
sed -n '/^## notice/,$p' "$P/.litopys/raw/n4.md" | expect "an unclosed tag runs to the end of the prompt" "still the reminder"
sed -n '/^## user/,/^## notice/p' "$P/.litopys/raw/n4.md" | refute "an unclosed tag takes nothing back into the user block" "never closed"

plain="plain words, \`\`\`a fence\`\`\` and  two  spaces${NL}"
say n5 "$plain"
eq "a prompt with no tags is written exactly as before" \
  "$(printf '\n## user · %s\n%s\n' "$NOW" "${plain%$NL}")" "$(sed -n '/^---$/,/^---$/!p' "$P/.litopys/raw/n5.md")"

# --- no git repo -> branch is '-' --------------------------------------------------------------
NG="$T/nogit"
mkdir -p "$NG"
printf '{"session_id":"s3","cwd":"%s","user_input":"no repo here"}' "$NG" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt
cat "$NG/.litopys/raw/s3.md" | expect "branch falls back to a dash" "branch: -"

# --- C9: the banner ------------------------------------------------------------------------
B="$T/banner"
mkdir -p "$B/docs/chronicle"
printf '# Chronicle 2026-08\n\n- 2026-08-03T10:00:00Z · note · a.md · older\n' > "$B/docs/chronicle/2026-08.md"
printf '# Chronicle 2026-09\n\n- 2026-09-21T12:34:56Z · ship · v0.1.0 · newest\n' > "$B/docs/chronicle/2026-09.md"
printf '## Q1 · owner-written, not a chronicle month\n' > "$B/docs/chronicle/golden-questions.md"
mkdir -p "$B/.litopys/raw/done"
printf 'x\n' > "$B/.litopys/raw/a.md"; printf 'x\n' > "$B/.litopys/raw/b.md"
printf 'x\n' > "$B/.litopys/raw/done/c.md"

out="$(printf '{"cwd":"%s","source":"startup"}' "$B" | bash "$START" 2>"$T/err2")"
eq "session-start exits 0" "0" "$?"
printf '%s' "$out" | jq -e . > /dev/null 2>&1
eq "banner is valid JSON" "0" "$?"
eq "hookEventName" "SessionStart" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"
eq "banner is exactly 6 lines" "6" "$(printf '%s\n' "$ctx" | wc -l | tr -d ' ')"
eq "every banner line is tagged" "0" "$(printf '%s\n' "$ctx" | grep -cv '^\[litopys\] ')"
printf '%s\n' "$ctx" | expect "line 1: version" "[litopys] v0.3.0 · project chronicle"
printf '%s\n' "$ctx" | expect "line 2: chronicle count" "[litopys] chronicle: docs/chronicle/ (2 files)"
printf '%s\n' "$ctx" | expect "line 3: last entry date" "[litopys] last entry: 2026-09-21"
printf '%s\n' "$ctx" | expect "line 4: distill pending count (top-level only)" "[litopys] distill: 2 pending · run /litopys:distill"
printf '%s\n' "$ctx" | expect "line 5: recall" "[litopys] recall: /litopys:recall <question>"
printf '%s\n' "$ctx" | sed -n 6p | expect "line 6: privacy, no repo" "[litopys] privacy: not a git repository - nothing to guard"
eq "systemMessage = the privacy line" "[litopys] privacy: not a git repository - nothing to guard" \
  "$(printf '%s' "$out" | jq -r '.systemMessage')"
no_file "no repo -> no .gitignore written" "$B/.gitignore"

# --- C17: the privacy guard runs every session and tells both the owner and the model ----------
GB="$T/banner-git"
mkdir -p "$GB"
git -C "$GB" init -q > /dev/null 2>&1 || git init -q "$GB" > /dev/null 2>&1
out="$(printf '{"cwd":"%s","source":"startup"}' "$GB" | bash "$START" 2>/dev/null)"
printf '%s' "$out" | jq -e . > /dev/null 2>&1
eq "git banner is valid JSON" "0" "$?"
msg="$(printf '%s' "$out" | jq -r '.systemMessage')"
printf '%s' "$msg" | expect "first session adds the block, loudly" "[litopys] PRIVACY: added .litopys/ docs/chronicle/ to .gitignore"
grep -qF '# >>> litopys' "$GB/.gitignore"
eq "the block landed in the project's .gitignore" "0" "$?"
ctx="$(printf '{"cwd":"%s"}' "$GB" | bash "$START" | jq -r '.hookSpecificOutput.additionalContext')"
eq "second session: still 6 lines" "6" "$(printf '%s\n' "$ctx" | wc -l | tr -d ' ')"
printf '%s\n' "$ctx" | sed -n 6p | expect "second session: all good" "[litopys] privacy: .litopys/ docs/chronicle/ git-ignored ✓"
printf '%s\n' "$ctx" | sed -n 6p | expect "the model is told never to force-add" "never git add -f these paths"
eq "block written once" "1" "$(grep -c '^# >>> litopys' "$GB/.gitignore")"

E="$T/empty-project"
mkdir -p "$E"
ctx="$(printf '{"cwd":"%s"}' "$E" | bash "$START" | jq -r '.hookSpecificOutput.additionalContext')"
printf '%s\n' "$ctx" | expect "no chronicle -> 0 files" "docs/chronicle/ (0 files)"
printf '%s\n' "$ctx" | expect "no chronicle -> last entry none" "last entry: none"
printf '%s\n' "$ctx" | expect "no journals -> nothing pending" "[litopys] distill: nothing pending"
no_file "the banner creates nothing" "$E/.litopys"

# --- fail-open: malformed, empty, missing cwd, unwritable, no jq ------------------------------
for mode in prompt stop end compact; do
  printf 'not json at all' | bash "$RAW" "$mode" > /dev/null 2>&1
  eq "$mode survives malformed stdin" "0" "$?"
  printf '' | bash "$RAW" "$mode" > /dev/null 2>&1
  eq "$mode survives empty stdin" "0" "$?"
  printf '[1,2]' | bash "$RAW" "$mode" > /dev/null 2>&1
  eq "$mode survives a non-object payload" "0" "$?"
done
# No cwd in the payload -> the banner falls back to the process's own directory, and the privacy
# guard writes there: run these from a throwaway dir, never from this repository.
( cd "$T" && printf 'not json at all' | bash "$START" > /dev/null 2>&1 )
eq "banner survives malformed stdin" "0" "$?"
( cd "$T" && printf '' | bash "$START" > "$T/out3" 2>&1 )
eq "banner survives empty stdin" "0" "$?"
jq -e . "$T/out3" > /dev/null 2>&1
eq "banner on empty stdin is still valid JSON" "0" "$?"

M="$T/nocwd"
mkdir -p "$M"
( cd "$M" && printf '{"session_id":"s9","user_input":"no cwd key"}' | LITOPYS_NOW="$NOW" bash "$RAW" prompt )
eq "prompt without cwd exits 0" "0" "$?"
cat "$M/.litopys/raw/s9.md" 2>/dev/null | expect "no cwd falls back to the cwd of the process" "no cwd key"

# A journal is a verbatim transcript: when .litopys/.gitignore cannot be written, none is kept.
FC="$T/failclosed"
mkdir -p "$FC/.litopys/.gitignore"   # a directory where the self-ignore file must go
printf '{"session_id":"s12","cwd":"%s","user_input":"secret plans"}' "$FC" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt > /dev/null 2>&1
eq "prompt exits 0 when the self-ignore cannot be written" "0" "$?"
no_file "no self-ignore means no journal (fail closed)" "$FC/.litopys/raw/s12.md"

U="$T/unwritable"
mkdir -p "$U"
printf 'I am a file, not a directory\n' > "$U/.litopys"   # mkdir -p .litopys/raw must fail
printf '{"session_id":"s10","cwd":"%s","user_input":"nowhere to go"}' "$U" \
  | LITOPYS_NOW="$NOW" bash "$RAW" prompt > /dev/null 2>&1
eq "prompt exits 0 when .litopys cannot be created" "0" "$?"

NOBIN="$T/nobin"
mkdir -p "$NOBIN"
BASH_ABS="$(command -v bash)"   # PATH is about to be emptied; bash itself must still be findable
printf '{"session_id":"s11","cwd":"%s","user_input":"jq is gone"}' "$P" \
  | PATH="$NOBIN" "$BASH_ABS" "$RAW" prompt > "$T/out4" 2>&1
eq "raw-journal exits 0 without jq" "0" "$?"
eq "raw-journal prints nothing without jq" "" "$(cat "$T/out4")"
no_file "no jq means no journal written" "$P/.litopys/raw/s11.md"
out="$(printf '{"cwd":"%s"}' "$B" | PATH="$NOBIN" "$BASH_ABS" "$START" 2>&1)"
eq "session-start exits 0 without jq" "0" "$?"
printf '%s' "$out" | expect "no jq gives the static C9 line" "[litopys] jq not found - raw journal disabled"
printf '%s' "$out" | jq -e . > /dev/null 2>&1
eq "the static fallback is still valid JSON" "0" "$?"
printf '%s' "$out" | expect "no jq still runs the privacy guard" "[litopys] PRIVACY: git not found"
printf '%s' "$out" | expect "no jq still tells the owner" '"systemMessage":"[litopys] PRIVACY'

# No jq but git present: the guard writes the block and the model still gets the no-force rule.
# Only possible where jq lives in a directory of its own (it does under winget, not in /usr/bin).
JQDIR="$(dirname "$(command -v jq)")"
NOJQ_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$JQDIR" | paste -sd: -)"
if PATH="$NOJQ_PATH" command -v git > /dev/null 2>&1 && ! PATH="$NOJQ_PATH" command -v jq > /dev/null 2>&1; then
  NG2="$T/nojq-git"
  mkdir -p "$NG2"
  git -C "$NG2" init -q > /dev/null 2>&1
  out="$(cd "$NG2" && printf '{"cwd":"%s"}' "$NG2" | PATH="$NOJQ_PATH" bash "$START" 2>&1)"
  printf '%s' "$out" | jq -e . > /dev/null 2>&1
  eq "no jq + git: still valid JSON" "0" "$?"
  printf '%s' "$out" | jq -r .systemMessage | expect "no jq + git: the block is added" "[litopys] PRIVACY: added .litopys/ docs/chronicle/ to .gitignore"
  printf '%s' "$out" | jq -r .hookSpecificOutput.additionalContext | expect "no jq + git: the model gets the no-force rule" "never git add -f these paths"
else
  echo "  skip  no jq + git: jq shares a directory with git on this machine"
fi

# plugin_root without CLAUDE_PLUGIN_ROOT and without a slash in $0: the guard must still be found.
ctx="$(cd "$SRC/hooks" && printf '{"cwd":"%s"}' "$B" | env -u CLAUDE_PLUGIN_ROOT bash session-start.sh \
  | jq -r '.hookSpecificOutput.additionalContext')"
printf '%s\n' "$ctx" | sed -n 6p | refute "a slash-less \$0 still finds bin/litopys" "guard did not run"

if [ -s "$FAILED" ]; then
  echo "hooks.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "hooks.test.sh: all green"
exit 0
