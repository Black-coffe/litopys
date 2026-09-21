#!/usr/bin/env bash
# `bin/litopys append` - the on-disk chronicle line (C1, C2, C3). No model, no jq, no python.
#
#   Usage: bash tests/append.test.sh            # from the litopys repo root
#
# Mirrors VULYK's test style: throwaway dirs under mktemp -d, expect() on stdout substrings,
# non-zero exit on the first wrong answer. Every assertion is about what landed on disk or
# what the command printed - never about the implementation's internals.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$SRC/bin/litopys"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# expect/refute read stdin, so they run in a pipeline subshell - a `fail=1` assigned there
# would be lost on return. Failures are recorded in a file instead; $FAILED is the verdict.
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
lines() { # lines <file>  - count of chronicle records (0 when the file does not exist)
  local c; c="$(grep -c '^- ' "$1" 2>/dev/null)"; printf '%s\n' "${c:-0}"
}

NOW="2026-09-21T12:34:56Z"
MONTH="2026-09"

# --- project A: has scripts/redact.sh, root given by CLAUDE_PROJECT_DIR -------------------
A="$T/proj-a"
mkdir -p "$A/scripts"
cp "$SRC/scripts/redact.sh" "$A/scripts/redact.sh"
export CLAUDE_PROJECT_DIR="$A"
CHRON="$A/docs/chronicle/$MONTH.md"

out="$(LITOPYS_NOW="$NOW" bash "$CLI" append --kind grill --ref docs/grill/x.md --note "hello" 2>&1)"
eq "append exits 0" "0" "$?"
printf '%s' "$out" | expect "append prints the line" "- $NOW · grill · docs/grill/x.md · hello"
cat "$CHRON" | expect "chronicle header" "# Chronicle $MONTH"
cat "$CHRON" | expect "C3 line on disk" "- $NOW · grill · docs/grill/x.md · hello"
eq "one record after first append" "1" "$(lines "$CHRON")"

# --- idempotence on (ts, kind, ref) -------------------------------------------------------
out="$(LITOPYS_NOW="$NOW" bash "$CLI" append --kind grill --ref docs/grill/x.md --note "hello again" 2>&1)"
eq "rerun exits 0" "0" "$?"
eq "rerun writes nothing" "1" "$(lines "$CHRON")"
printf '%s' "$out" | expect "rerun prints the existing line" "· grill · docs/grill/x.md · hello"
printf '%s' "$out" | refute "rerun does not print the new note" "hello again"

LITOPYS_NOW="$NOW" bash "$CLI" append --kind grill --ref docs/grill/y.md --note "other ref" > /dev/null 2>&1
eq "different --ref appends" "2" "$(lines "$CHRON")"
LITOPYS_NOW="$NOW" bash "$CLI" append --kind note --ref docs/grill/x.md --note "other kind" > /dev/null 2>&1
eq "different --kind appends" "3" "$(lines "$CHRON")"

# --- a multi-line note stays one line -----------------------------------------------------
LITOPYS_NOW="2026-09-21T13:00:00Z" bash "$CLI" append --kind brief --ref docs/specs/s/brief.md \
  --note "$(printf 'first line\nsecond line')" > /dev/null 2>&1
eq "multi-line note is one record" "4" "$(lines "$CHRON")"
cat "$CHRON" | expect "newline collapsed to a space" "· brief · docs/specs/s/brief.md · first line second line"

# --- secrets are masked when scripts/redact.sh exists -------------------------------------
TOKEN="ghp_$(printf 'a%.0s' $(seq 36))"
LITOPYS_NOW="2026-09-21T14:00:00Z" bash "$CLI" append --kind note --ref sec.md --note "token $TOKEN here" > /dev/null 2>&1
cat "$CHRON" | refute "github token masked with redact.sh present" "$TOKEN"
cat "$CHRON" | expect "masked record still written" "· note · sec.md · token "

# --- project B: no scripts/redact.sh -> passthrough, no crash -----------------------------
B="$T/proj-b"
mkdir -p "$B"
export CLAUDE_PROJECT_DIR="$B"
out="$(LITOPYS_NOW="2026-09-21T14:00:00Z" bash "$CLI" append --kind note --ref sec.md --note "token $TOKEN here" 2>&1)"
eq "passthrough append exits 0" "0" "$?"
printf '%s' "$out" | expect "no redact.sh -> note passes through" "$TOKEN"
eq "project B wrote its own chronicle" "1" "$(lines "$B/docs/chronicle/$MONTH.md")"

# --- argument errors: exit 2, usage on stderr, nothing written ----------------------------
C="$T/proj-c"
mkdir -p "$C"
export CLAUDE_PROJECT_DIR="$C"
err="$(LITOPYS_NOW="$NOW" bash "$CLI" append --kind bogus --ref x.md --note "n" 2>&1 >/dev/null)"
eq "--kind bogus exits 2" "2" "$?"
printf '%s' "$err" | expect "--kind bogus prints usage to stderr" "litopys append --kind"
err="$(LITOPYS_NOW="$NOW" bash "$CLI" append --kind grill --note "n" 2>&1 >/dev/null)"
eq "missing --ref exits 2" "2" "$?"
printf '%s' "$err" | expect "missing --ref names the flag" "--ref is required"
if [ -e "$C/docs/chronicle" ]; then
  bad "argument errors must not write - $C/docs/chronicle exists"
else echo "  ok    argument errors write nothing"; fi

# --- C1 fallback: no CLAUDE_PROJECT_DIR -> git toplevel -----------------------------------
D="$T/proj-d"
mkdir -p "$D/sub/deeper"
( cd "$D" && git init -q -b main . && git config user.email t@t && git config user.name "T" )
unset CLAUDE_PROJECT_DIR
( cd "$D/sub/deeper" && LITOPYS_NOW="$NOW" bash "$CLI" append --kind ship --ref v0.1.0 --note "from a subdir" > /dev/null 2>&1 )
eq "git toplevel is the root" "1" "$(lines "$D/docs/chronicle/$MONTH.md")"
if [ -e "$D/sub/deeper/docs" ]; then
  bad "wrote into the cwd instead of the git toplevel"
else echo "  ok    nothing written under the cwd"; fi

# --- plumbing ------------------------------------------------------------------------------
ver="$(bash "$CLI" --version 2>&1)"
eq "--version exits 0" "0" "$?"
printf '%s' "$ver" | expect "--version prints 0.1.0" "0.1.0"
cat "$SRC/.gitignore" | expect ".gitignore ignores .litopys/" ".litopys/"

if [ -s "$FAILED" ]; then
  echo "append.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "append.test.sh: all green"
exit 0
