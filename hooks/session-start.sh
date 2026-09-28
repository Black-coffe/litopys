#!/usr/bin/env bash
# litopys SessionStart banner - six lines of state, no model, no network (C9, C17).
#
#   Usage (hook only, payload JSON on stdin):
#     bash hooks/session-start.sh
#
# Prints one JSON object. hookSpecificOutput.additionalContext carries exactly six [litopys]
# lines for the model - counts only, it never asks the model to do anything. Line 6 is the
# privacy guard (`bin/litopys privacy`, run every session): it re-ensures the litopys block in
# the project's .gitignore and its status also goes to the owner as the top-level systemMessage.
set -u

# ${0%/*}, not dirname: the no-jq path below must work with nothing but bash itself.
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "${0%/*}/.." 2>/dev/null && pwd)}"

privacy_line() { # privacy_line [root] - the guard's one line, or a loud line when the guard itself failed
  local line
  if [ -n "${1:-}" ]; then
    line="$(CLAUDE_PROJECT_DIR="$1" "$BASH" "$plugin_root/bin/litopys" privacy 2>/dev/null < /dev/null)"
  else
    line="$("$BASH" "$plugin_root/bin/litopys" privacy 2>/dev/null < /dev/null)"
  fi
  [ -n "$line" ] || line="[litopys] PRIVACY: guard did not run - check that .gitignore covers .litopys/ and docs/chronicle/"
  printf '%s' "$line"
}

# With jq absent the banner degrades to one honest static line - but the privacy guard still
# runs: it needs no jq, and its line never contains `"` or `\`, so it is embedded as is.
if ! command -v jq > /dev/null 2>&1; then
  privacy="$(privacy_line)"
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[litopys] jq not found - raw journal disabled\\n%s"}}\n' "$privacy" "$privacy"
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

version="$(jq -r '.version // empty' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null || true)"
[ -n "$version" ] || version="0.3.0"

count_md() { # count_md <dir> [glob] - files matching <glob> (default *.md) directly in <dir>
  local n=0 f
  for f in "$1"/${2:-*.md}; do [ -f "$f" ] && n=$((n + 1)); done
  printf '%s' "$n"
}

# Month files only: golden-questions.md lives in docs/chronicle/ too, and it is no chronicle.
chronicles="$(count_md "$root/docs/chronicle" '[0-9][0-9][0-9][0-9]-[0-9][0-9].md')"
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

# C17 - the guard runs against the same root the banner counts in.
privacy="$(privacy_line "$root")"
case "$privacy" in
  *"not a git repository"*|*"git not found"*) privacy_ctx="$privacy" ;;
  *) privacy_ctx="$privacy · never git add -f these paths" ;;
esac

ctx="$(printf '%s\n%s\n%s\n%s\n%s\n%s' \
  "[litopys] v$version · project chronicle" \
  "[litopys] chronicle: docs/chronicle/ ($chronicles files)" \
  "[litopys] last entry: $last" \
  "$distill_line" \
  "[litopys] recall: /litopys:recall <question>" \
  "$privacy_ctx")"

jq -nc --arg ctx "$ctx" --arg msg "$privacy" \
  '{systemMessage:$msg,hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}' 2>/dev/null || true
exit 0
