#!/usr/bin/env bash
# litopys SessionStart banner - five lines of state, no model, no network (C9).
#
#   Usage (hook only, payload JSON on stdin):
#     bash hooks/session-start.sh
#
# Prints one JSON object with hookSpecificOutput.additionalContext; that string is the only
# thing that reaches the session's context, so it stays at exactly five [litopys] lines and
# reports counts only - it never asks the model to do anything (that is phase 2).
set -u

# Nothing external runs before this check: with jq absent the banner degrades to one honest
# static line instead of failing the session start.
if ! command -v jq > /dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[litopys] jq not found - raw journal disabled"}}'
  exit 0
fi

payload="$(cat 2>/dev/null || true)"
cwd=""
if [ -n "$payload" ]; then
  cwd="$(printf '%s' "$payload" | jq -r 'if type == "object" then (.cwd // empty) else empty end' 2>/dev/null || true)"
fi

# C1 - project root: CLAUDE_PROJECT_DIR, then the payload's cwd, then git toplevel, then $PWD.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
  root="$CLAUDE_PROJECT_DIR"
elif [ -n "$cwd" ] && [ -d "$cwd" ]; then
  root="$cwd"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] && [ -d "$root" ] || root="$PWD"
fi

plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
version="$(jq -r '.version // empty' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null || true)"
[ -n "$version" ] || version="0.2.0"

count_md() { # count_md <dir> - .md files directly in <dir>, 0 when it does not exist
  local n=0 f
  for f in "$1"/*.md; do [ -f "$f" ] && n=$((n + 1)); done
  printf '%s' "$n"
}

chronicles="$(count_md "$root/docs/chronicle")"
raws="$(count_md "$root/.litopys/raw")"

if [ "$raws" -gt 0 ]; then
  distill_line="[litopys] distill: $raws pending · run /litopys:distill"
else
  distill_line="[litopys] distill: nothing pending"
fi

# Last entry = the newest date on any C3 chronicle line, across every month file.
last="$(cat "$root"/docs/chronicle/*.md 2>/dev/null \
  | grep -o '^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' 2>/dev/null \
  | cut -c3-12 | sort | tail -1)"
[ -n "$last" ] || last="none"

ctx="$(printf '%s\n%s\n%s\n%s\n%s' \
  "[litopys] v$version · project chronicle" \
  "[litopys] chronicle: docs/chronicle/ ($chronicles files)" \
  "[litopys] last entry: $last" \
  "$distill_line" \
  "[litopys] recall: /litopys:recall <question>")"

jq -nc --arg ctx "$ctx" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null || true
exit 0
