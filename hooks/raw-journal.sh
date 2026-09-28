#!/usr/bin/env bash
# litopys raw journal - the per-session transcript the hooks write without a model (C7, C8).
#
#   Usage (hook only, payload JSON on stdin):
#     bash hooks/raw-journal.sh prompt   # UserPromptSubmit -> '## user · <ts>'
#     bash hooks/raw-journal.sh stop     # Stop             -> '## assistant · <ts>'
#     bash hooks/raw-journal.sh end      # SessionEnd       -> '## closed · <ts> · <reason>'
#     bash hooks/raw-journal.sh compact  # PreCompact       -> '## compact · <ts> · <trigger>'
#
# Writes <root>/.litopys/raw/<session_id>.md and nothing else. Never prints to stdout - a
# hook that talks pollutes the session it is recording. Fail-open everywhere: a journal that
# cannot be written must not break the session that was going to be journalled, so every
# failure path is `exit 0`. `end` runs inside SessionEnd's 1.5 s budget (no `timeout` in
# hooks.json), so it does one append and nothing more - no git, no mkdir, no scan.
set -u

MODE="${1:-}"
case "$MODE" in prompt|stop|end|compact) : ;; *) exit 0 ;; esac

# jq is the only parser (plan assumption). Nothing external runs before this check, so an
# empty PATH is a silent no-op rather than a crash.
command -v jq > /dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
printf '%s' "$payload" | jq -e 'type == "object"' > /dev/null 2>&1 || exit 0

field() { # field <key> - the payload's string value, empty when absent or null
  printf '%s' "$payload" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null || true
}

# Subagent Stop events carry agent_id; their turns belong to a fork, not to this session (C7).
if [ "$MODE" = "stop" ] && [ -n "$(field agent_id)" ]; then
  exit 0
fi

sid="$(field session_id)"
# The id becomes a filename: keep it to characters every filesystem accepts.
sid="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')"
[ -n "$sid" ] || exit 0

cwd="$(field cwd)"
# C1 - project root: CLAUDE_PROJECT_DIR, then the payload's cwd, then git toplevel, then $PWD.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
  root="$CLAUDE_PROJECT_DIR"
elif [ -n "$cwd" ] && [ -d "$cwd" ]; then
  root="$cwd"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] && [ -d "$root" ] || root="$PWD"
fi

file="$root/.litopys/raw/$sid.md"
ts="${LITOPYS_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

journal_end() { # SessionEnd: one append, only into a journal that already exists.
  [ -f "$file" ] || return 0
  printf '\n## closed · %s · %s\n' "$ts" "${1:--}" >> "$file" 2>/dev/null || true
}

journal_compact() { # PreCompact: one append, only into a journal that already exists (C13).
  [ -f "$file" ] || return 0
  printf '\n## compact · %s · %s\n' "$ts" "${1:--}" >> "$file" 2>/dev/null || true
}

ensure_journal() { # create the C8 frontmatter on the first block of the session
  # C1 - .litopys/ ignores itself (the host's .gitignore block is the second fence, C17). A
  # journal is a verbatim transcript: when the self-ignore cannot be written, nothing is
  # journalled (fail closed), and the check runs on every block, not only the first.
  mkdir -p "$root/.litopys/raw" 2>/dev/null || return 1
  [ -f "$root/.litopys/.gitignore" ] || printf '*\n' > "$root/.litopys/.gitignore" 2>/dev/null || return 1
  [ -f "$file" ] && return 0
  local branch gdir
  gdir="${cwd:-$root}"
  # symbolic-ref first: on a branch with no commits yet, rev-parse --abbrev-ref prints "HEAD".
  branch="$(git -C "$gdir" symbolic-ref --short HEAD 2>/dev/null || git -C "$gdir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$branch" ] || branch="-"
  {
    printf -- '---\n'
    printf 'litopys: raw\n'
    printf 'version: 1\n'
    printf 'session_id: %s\n' "$sid"
    printf 'started: %s\n' "$ts"
    printf 'cwd: %s\n' "${cwd:-$root}"
    printf 'branch: %s\n' "$branch"
    printf -- '---\n'
  } > "$file" 2>/dev/null || return 1
}

append_block() { # append_block <label> <verbatim text>
  [ -n "$2" ] || return 0
  ensure_journal || return 0
  { printf '\n## %s · %s\n' "$1" "$ts"; printf '%s\n' "$2"; } >> "$file" 2>/dev/null || true
}

case "$MODE" in
  # The brief says user_input, the docs say prompt: read whichever arrived.
  prompt) append_block user "$(printf '%s' "$payload" | jq -r '.user_input // .prompt // empty' 2>/dev/null)" ;;
  stop)   append_block assistant "$(field last_assistant_message)" ;;
  end)    journal_end "$(field reason)" ;;
  compact) journal_compact "$(printf '%s' "$payload" | jq -r '.compaction_trigger // .trigger // "-"' 2>/dev/null)" ;;
esac
exit 0
