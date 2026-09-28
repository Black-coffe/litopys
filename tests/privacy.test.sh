#!/usr/bin/env bash
# The privacy guard - `bin/litopys privacy` and the .gitignore block every writer ensures (C17).
#
#   Usage: bash tests/privacy.test.sh             # from the litopys repo root
#
# Same style as the other suites: throwaway `git init` repos under mktemp -d, assertions about
# what landed in .gitignore, what git reports as ignored or tracked, and the one status line.
# No model, no network. The guard must never touch the index, so every case also checks that.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$SRC/bin/litopys"
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
ignored() { # ignored <root> <path> - 0 when git's own matcher ignores <path>
  git -C "$1" check-ignore -q --no-index -- "$2"
}

unset CLAUDE_PROJECT_DIR LITOPYS_TRACK_CHRONICLE 2>/dev/null || true

newrepo() { # newrepo <name> - an empty repo; prints its root
  local r="$T/$1"
  mkdir -p "$r"
  git -C "$r" init -q > /dev/null 2>&1 || git init -q "$r" > /dev/null 2>&1
  git -C "$r" config user.email "t@example.com"
  git -C "$r" config user.name "Test"
  git -C "$r" config commit.gpgsign false
  git -C "$r" config core.autocrlf false
  printf '%s\n' "$r"
}
guard() { CLAUDE_PROJECT_DIR="$1" bash "$CLI" privacy 2>/dev/null; }

# --- G1: no .gitignore -> the block is created, then left alone ------------------------------
R="$(newrepo g1)"
guard "$R" | expect "G1 first run says it added the block" "[litopys] PRIVACY: added .litopys/ docs/chronicle/ to .gitignore - commit it"
for p in .litopys/raw/x.md sub/.litopys/raw/x.md docs/chronicle/2026-09.md docs/chronicle/sessions/x.md; do
  ignored "$R" "$p"; eq "G1 $p is git-ignored" "0" "$?"
done
ignored "$R" docs/chronicle/golden-questions.md
eq "G1 golden-questions.md (owner-written) stays trackable" "1" "$?"
before="$(cat "$R/.gitignore")"
guard "$R" | expect "G1 second run is the quiet ok line" "[litopys] privacy: .litopys/ docs/chronicle/ git-ignored ✓"
eq "G1 second run changes nothing" "$before" "$(cat "$R/.gitignore")"
eq "G1 the guard never stages anything" "" "$(git -C "$R" diff --cached --name-only)"

# --- G2: an owner's .gitignore - appended after their lines, CRLF and no final newline ---------
R="$(newrepo g2)"
printf 'node_modules/\r\n*.log' > "$R/.gitignore"
guard "$R" > /dev/null
head -n 1 "$R/.gitignore" | expect "G2 owner's first line kept" "node_modules/"
sed -n 2p "$R/.gitignore" | expect "G2 owner's last line kept whole" "*.log"
eq "G2 one block" "1" "$(grep -c '^# >>> litopys' "$R/.gitignore")"
ignored "$R" docs/chronicle/sessions/x.md; eq "G2 chronicle ignored after append" "0" "$?"
ignored "$R" build.log; eq "G2 owner's own rule still works" "0" "$?"

# --- G3: a hand-edited block is rewritten in place, never duplicated ---------------------------
R="$(newrepo g3)"
printf 'a/\n# >>> litopys old marker >>>\n.litopys/\n# <<< litopys <<<\nz/\n' > "$R/.gitignore"
guard "$R" | expect "G3 edited block is reported" "rewrote the litopys block"
eq "G3 still one block" "1" "$(grep -c '^# >>> litopys' "$R/.gitignore")"
head -n 1 "$R/.gitignore" | expect "G3 line before the block kept" "a/"
tail -n 1 "$R/.gitignore" | expect "G3 line after the block kept" "z/"
ignored "$R" docs/chronicle/x.md; eq "G3 chronicle ignored after rewrite" "0" "$?"

# --- G4: a begin marker with no end never swallows the owner's lines ---------------------------
R="$(newrepo g4)"
printf '# >>> litopys dangling\nkeep-me/\n' > "$R/.gitignore"
guard "$R" > /dev/null
grep -qx 'keep-me/' "$R/.gitignore"; eq "G4 owner's line after a dangling marker survives" "0" "$?"
guard "$R" > /dev/null
grep -qx 'keep-me/' "$R/.gitignore"; eq "G4 ... and survives the next session too" "0" "$?"
guard "$R" | expect "G4 then settles on ok" "git-ignored ✓"

# --- G5: files tracked before the block -> loud, with the command, index untouched -------------
R="$(newrepo g5)"
mkdir -p "$R/docs/chronicle/sessions"
printf 'x\n' > "$R/docs/chronicle/2026-09.md"
printf 'x\n' > "$R/docs/chronicle/sessions/a.md"
printf 'q\n' > "$R/docs/chronicle/golden-questions.md"
git -C "$R" add -A > /dev/null 2>&1
git -C "$R" commit -qm seed > /dev/null 2>&1
guard "$R" > /dev/null
out="$(guard "$R")"
printf '%s' "$out" | expect "G5 loud" "[litopys] PRIVACY:"
printf '%s' "$out" | expect "G5 counts the tracked litopys files (not golden-questions)" "2 litopys file(s) already tracked by git"
printf '%s' "$out" | expect "G5 gives the ready command" "git ls-files -ci --exclude-standard -z -- .litopys '*/.litopys/*' docs/chronicle | xargs -0 git rm --cached --quiet --"
eq "G5 index untouched" "3" "$(git -C "$R" ls-files | grep -c chronicle)"
eq "G5 nothing staged" "" "$(git -C "$R" diff --cached --name-only)"
printed() { # printed <status line> - the untrack command exactly as the guard printed it
  local c="${1#*untrack: }"; printf '%s' "${c%% ; then commit*}"
}
( cd "$R" && eval "$(printed "$out")" ) > /dev/null 2>&1
eq "G5 the printed command runs" "0" "$?"
guard "$R" | expect "G5 after the printed command: ok" "git-ignored ✓"
git -C "$R" ls-files | expect "G5 the command keeps golden-questions tracked" "docs/chronicle/golden-questions.md"

# --- G5b: a nested sub/.litopys/ is counted and the printed command clears it too ---------------
R="$(newrepo g5b)"
mkdir -p "$R/sub/.litopys/raw"
printf 'j\n' > "$R/sub/.litopys/raw/j.md"
git -C "$R" add -A > /dev/null 2>&1
git -C "$R" commit -qm seed > /dev/null 2>&1
out="$(guard "$R")"
printf '%s' "$out" | expect "G5b nested tracked journal counted" "1 litopys file(s) already tracked by git"
( cd "$R" && eval "$(printed "$out")" ) > /dev/null 2>&1
eq "G5b the printed command runs" "0" "$?"
guard "$R" | expect "G5b ... and clears the warning" "git-ignored ✓"

# --- G6: a later rule that undoes the block is reported, not patched --------------------------
R="$(newrepo g6)"
guard "$R" > /dev/null
printf '!docs/chronicle/sessions/\n' >> "$R/.gitignore"
guard "$R" | expect "G6 override is loud" "NOT ignored: docs/chronicle/sessions/ - a later .gitignore rule overrides the litopys block"
tail -n 1 "$R/.gitignore" | expect "G6 the owner's rule is left where it is" "!docs/chronicle/sessions/"

# --- G6b: a rule that un-ignores real month files while every probe name stays ignored ----------
# (`!docs/chronicle/sessions/2026-*` would not do it: git never re-includes a file whose parent
# directory is excluded, and `docs/chronicle/*` excludes `sessions/` itself.)
R="$(newrepo g6b)"
guard "$R" > /dev/null
printf '!docs/chronicle/2026-*.md\n' >> "$R/.gitignore"
mkdir -p "$R/docs/chronicle"
printf -- '- line\n' > "$R/docs/chronicle/2026-09.md"
ignored "$R" docs/chronicle/probe.md; eq "G6b every probe name is still ignored" "0" "$?"
guard "$R" | expect "G6b real files git would add are loud" "1 litopys file(s) NOT ignored - git would add them"

# --- G7: the owner's opt-in - docs/chronicle/ trackable, .litopys/ never ----------------------
R="$(newrepo g7)"
guard "$R" > /dev/null
LITOPYS_TRACK_CHRONICLE=1 CLAUDE_PROJECT_DIR="$R" bash "$CLI" privacy 2>/dev/null \
  | expect "G7 opt-in rewrites the block" "rewrote the litopys block"
out="$(LITOPYS_TRACK_CHRONICLE=1 CLAUDE_PROJECT_DIR="$R" bash "$CLI" privacy 2>/dev/null)"
printf '%s' "$out" | expect "G7 opt-in ok line names it" "docs/chronicle/ tracked on purpose (LITOPYS_TRACK_CHRONICLE=1)"
ignored "$R" docs/chronicle/sessions/x.md; eq "G7 chronicle trackable under the opt-in" "1" "$?"
ignored "$R" .litopys/raw/x.md; eq "G7 .litopys/ still ignored under the opt-in" "0" "$?"
guard "$R" | expect "G7 dropping the opt-in restores the full block" "rewrote the litopys block"
ignored "$R" docs/chronicle/sessions/x.md; eq "G7 chronicle ignored again" "0" "$?"

# --- G8: not a git repository - nothing written ------------------------------------------------
N="$T/g8-nogit"
mkdir -p "$N"
guard "$N" | expect "G8 says there is nothing to guard" "[litopys] privacy: not a git repository - nothing to guard"
no_file "G8 no .gitignore in a non-git dir" "$N/.gitignore"

# --- G9: the CLI writers ensure the block too, with a note on stderr only ----------------------
R="$(newrepo g9)"
out="$(CLAUDE_PROJECT_DIR="$R" bash "$CLI" append --kind note --ref a.md --note hi 2>"$T/g9.err")"
printf '%s' "$out" | refute "G9 append's stdout stays the chronicle line" "git-ignored"
expect "G9 append notes the .gitignore change on stderr" "litopys: git-ignored .litopys/ docs/chronicle/" < "$T/g9.err"
ignored "$R" docs/chronicle/2026-09.md; eq "G9 the month file append wrote is ignored" "0" "$?"

# --- G11: recall can still search the git-ignored chronicle ---------------------------------
# Grep (ripgrep) skips ignored files; the command recall is told to use must find month files and
# session records anyway. The literal lives in agents/recall.md and the skill - checked here.
RECALL_CMD="git grep --no-index --no-exclude-standard -n -i -e"
grep -qF -- "$RECALL_CMD '<term>' -- docs/chronicle" "$SRC/agents/recall.md"
eq "G11 agents/recall.md names the ignored-file search" "0" "$?"
grep -qF -- "$RECALL_CMD '<term>' -- docs/chronicle" "$SRC/skills/recall/SKILL.md"
eq "G11 the recall skill names it too" "0" "$?"
grep -q '^allowed-tools:.*Bash(git grep:\*)' "$SRC/skills/recall/SKILL.md"
eq "G11 the recall skill may run git grep" "0" "$?"
R="$(newrepo g11)"
guard "$R" > /dev/null
mkdir -p "$R/docs/chronicle/sessions"
printf -- '- 2026-09-01T10:00:00Z · note · a.md · ZEBRA month\n' > "$R/docs/chronicle/2026-09.md"
printf 'ZEBRA record\n' > "$R/docs/chronicle/sessions/2026-09-01-abcdef12.md"
ignored "$R" docs/chronicle/2026-09.md; eq "G11 the month file is ignored" "0" "$?"
hits="$(cd "$R" && $RECALL_CMD 'zebra' -- docs/chronicle 2>/dev/null)"
printf '%s' "$hits" | expect "G11 the search finds the ignored month file" "docs/chronicle/2026-09.md"
printf '%s' "$hits" | expect "G11 the search finds the ignored session record" "docs/chronicle/sessions/2026-09-01-abcdef12.md"

# --- G12: a symlinked .gitignore is checked, never written through ---------------------------
R="$(newrepo g12)"
ln -s "$T/g12-outside" "$R/.gitignore" 2> /dev/null
if [ -L "$R/.gitignore" ]; then
  guard "$R" > /dev/null
  no_file "G12 a dangling symlink is not followed out of the project" "$T/g12-outside"
  [ -L "$R/.gitignore" ]; eq "G12 the symlink itself is left alone" "0" "$?"
else
  rm -f "$R/.gitignore"
  echo "  skip  G12 this filesystem made a copy, not a symlink (Windows without symlink rights)"
fi

# --- G10: the status line never carries a quote or a backslash (embedded raw in JSON) ----------
for r in "$T"/g*/; do   # directories only: a file path is no project root and would fall
                       # back to the git toplevel of this very repository
  out="$(guard "${r%/}")"
  case "$out" in *'"'*|*'\'*) bad "G10 $r: quote or backslash in '$out'" ;; esac
  printf '{"m":"%s"}' "$out" | jq -e . > /dev/null 2>&1 || bad "G10 $r: not embeddable raw in JSON: '$out'"
done
echo "  ok    G10 no quote or backslash in any status line"
eq "G10 privacy takes no arguments" "2" "$(bash "$CLI" privacy --fix > /dev/null 2>&1; echo $?)"

if [ -s "$FAILED" ]; then
  echo "privacy.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "privacy.test.sh: all green"
exit 0
