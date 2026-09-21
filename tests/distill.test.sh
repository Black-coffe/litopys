#!/usr/bin/env bash
# `bin/litopys distill record` - the session record on disk (C11, C13, C14, C16). No model.
#
#   Usage: bash tests/distill.test.sh          # from the litopys repo root
#
# Same style as tests/append.test.sh: throwaway dirs under mktemp -d, assertions only about
# what landed on disk or what the command printed. The four helpers are copied, not sourced -
# there is no tests/lib.sh yet (plan ## Assumptions).
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$SRC/bin/litopys"
FIX="$SRC/tests/fixtures"
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
lines() { # lines <file>  - count of chronicle records (0 when the file does not exist)
  local c; c="$(grep -c '^- ' "$1" 2>/dev/null)"; printf '%s\n' "${c:-0}"
}
no_file() { # no_file <label> <path>
  if [ -e "$2" ]; then bad "$1 - $2 exists"; else echo "  ok    $1"; fi
}

SID="f00dcafe-1111-2222-3333-444455556666"
SID8="f00dcafe"
RDATE="2026-09-20"
REL="docs/chronicle/sessions/$RDATE-$SID8.md"
NOW="2026-09-21T12:00:00Z"
MONTH="2026-09"
SECRET="sk-abcdefghijklmnopqrstuvwxyz012345"
TOKEN="ghp_abcdefghijklmnopqrstuvwxyz0123456789"

newproj() { # newproj <name> - a host project with a queued journal; prints its root
  local p="$T/$1"
  mkdir -p "$p/.litopys/raw"
  cp "$FIX/raw-resume.md" "$p/.litopys/raw/$SID.md"
  printf '%s\n' "$p"
}

# --- fixtures are what the story says they are --------------------------------------------
cat "$FIX/raw-resume.md" | expect "fixture has a mid-file closed marker" "## closed · 2026-09-20T09:40:00Z"
cat "$FIX/raw-resume.md" | expect "fixture resumes past it" "## user · 2026-09-20T10:02:11Z"
cat "$FIX/raw-resume.md" | expect "fixture has a compact block" "## compact · 2026-09-20T10:31:00Z · auto"
cat "$FIX/raw-resume.md" | expect "fixture ends closed" "## closed · 2026-09-20T11:05:09Z"
cat "$FIX/raw-resume.md" | expect "fixture carries an sk- string" "$SECRET"
cat "$FIX/distill-body.md" | expect "body fixture has a title" "# Resume and compaction survive one journal"
cat "$FIX/distill-body.md" | expect "body fixture carries a ghp_ token" "$TOKEN"
for f in "$FIX/raw-resume.md" "$FIX/distill-body.md" "$CLI" "$SRC/tests/distill.test.sh" "$SRC/scripts/redact.sh"; do
  if LC_ALL=C grep -q $'\r' "$f"; then bad "CRLF in $f"; else echo "  ok    LF only: $(basename "$f")"; fi
done

# --- P1: plugin's own redact.sh, no host copy ----------------------------------------------
P="$(newproj proj-a)"
export CLAUDE_PROJECT_DIR="$P"
export CLAUDE_PLUGIN_ROOT="$SRC"
REC="$P/$REL"
CHRON="$P/docs/chronicle/$MONTH.md"

out="$(LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$P/.litopys/raw/$SID.md" \
  --body "$FIX/distill-body.md" --topics a,b --links docs/x.md,abc1234 2>&1)"
eq "distill record exits 0" "0" "$?"
printf '%s' "$out" | expect "prints the record path" "$REL"
if [ -f "$REC" ]; then echo "  ok    record written"; else bad "no record at $REC"; fi

keys="$(sed -n '2,13p' "$REC" | cut -d: -f1 | tr '\n' ' ')"
eq "C11 frontmatter keys, in C11 order" \
  "litopys version date session_id started ended branch topics links source tokens model " "$keys"
eq "record opens with ---" "---" "$(sed -n '1p' "$REC")"
eq "frontmatter closes at line 14" "---" "$(sed -n '14p' "$REC")"
fm() { sed -n "s/^$1: //p" "$REC" | head -n 1; }
eq "date from started" "$RDATE" "$(fm date)"
eq "session_id from the journal" "$SID" "$(fm session_id)"
eq "started from the journal" "2026-09-20T09:15:00Z" "$(fm started)"
eq "ended is the final closed marker (C13)" "2026-09-20T11:05:09Z" "$(fm ended)"
eq "branch from the journal" "feature/resume" "$(fm branch)"
eq "topics list" "[a, b]" "$(fm topics)"
eq "links list" "[docs/x.md, abc1234]" "$(fm links)"
eq "source defaults to live" "live" "$(fm source)"
eq "model defaults to sonnet" "sonnet" "$(fm model)"
tok="$(fm tokens)"
case "$tok" in (*[!0-9]*|"") bad "tokens is not an integer: '$tok'" ;; (*) echo "  ok    tokens is an integer" ;; esac

cat "$REC" | refute "ghp_ token masked in the record" "$TOKEN"
cat "$REC" | expect "the mask is the one redact.sh writes" "[VULYK:REDACTED]"
cat "$REC" | refute "the journal's sk- string never reaches the record" "$SECRET"
cat "$REC" | expect "body title kept" "# Resume and compaction survive one journal"
cat "$REC" | expect "body sections kept" "## Brainstorm"

eq "exactly one chronicle line" "1" "$(lines "$CHRON")"
cat "$CHRON" | expect "C3 session line" \
  "- $NOW · session · $REL · Resume and compaction survive one journal"
if [ -f "$P/.litopys/raw/done/$SID.md" ]; then echo "  ok    journal moved to done/"
else bad "journal not at .litopys/raw/done/$SID.md"; fi
no_file "journal gone from the top level" "$P/.litopys/raw/$SID.md"

eq "one distill.jsonl row" "1" "$(grep -c . "$P/.litopys/distill.jsonl")"
row="$(cat "$P/.litopys/distill.jsonl")"
for k in '"ts":' '"session_id":' '"record":' '"journal_bytes":' '"body_bytes":' '"tokens_est":' '"model":' '"source":' '"litopys":'; do
  printf '%s' "$row" | expect "C14 row has $k" "$k"
done
printf '%s' "$row" | expect "row names the record" "\"record\":\"$REL\""
jb="$(printf '%s' "$row" | sed -n 's/.*"journal_bytes":\([0-9]*\).*/\1/p')"
bb="$(printf '%s' "$row" | sed -n 's/.*"body_bytes":\([0-9]*\).*/\1/p')"
te="$(printf '%s' "$row" | sed -n 's/.*"tokens_est":\([0-9]*\).*/\1/p')"
eq "journal_bytes is the journal's size" "$(wc -c < "$FIX/raw-resume.md" | tr -dc '0-9')" "$jb"
eq "body_bytes is the body's size" "$(wc -c < "$FIX/distill-body.md" | tr -dc '0-9')" "$bb"
eq "tokens_est = (journal + body) / 4" "$(( (jb + bb) / 4 ))" "$te"
eq "record tokens = tokens_est" "$te" "$tok"

# --- P2: a host scripts/redact.sh outranks the plugin's copy (C16) -------------------------
H="$(newproj proj-host)"
mkdir -p "$H/scripts"
printf '#!/usr/bin/env bash\nwhile IFS= read -r l; do echo HOSTMASK; done\nexit 0\n' > "$H/scripts/redact.sh"
export CLAUDE_PROJECT_DIR="$H"
LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$H/.litopys/raw/$SID.md" \
  --body "$FIX/distill-body.md" > /dev/null 2>&1
cat "$H/$REL" | expect "host redact.sh wins for the record" "HOSTMASK"
cat "$H/$REL" | refute "plugin mask absent when the host has its own" "[VULYK:REDACTED]"
# The host filter masks every line it sees, so the C3 amendment's redacted --ref shows it too.
cat "$H/docs/chronicle/$MONTH.md" | expect "host redact.sh wins for the chronicle note" "· session · HOSTMASK · HOSTMASK"

# --- P3: a second run needs --force ---------------------------------------------------------
export CLAUDE_PROJECT_DIR="$P"
cp "$FIX/raw-resume.md" "$P/.litopys/raw/$SID.md"
err="$(LITOPYS_NOW="2026-09-21T13:00:00Z" bash "$CLI" distill record --journal "$P/.litopys/raw/$SID.md" \
  --body "$FIX/distill-body.md" 2>&1 >/dev/null)"
eq "second run without --force exits 2" "2" "$?"
printf '%s' "$err" | expect "stderr names the record" "$REL"
eq "no second chronicle line" "1" "$(lines "$CHRON")"
if [ -f "$P/.litopys/raw/$SID.md" ]; then echo "  ok    refused run leaves the journal queued"
else bad "refused run moved the journal"; fi

printf '# Second pass title\n\n## Decisions\n- d\n\n## Problems\n- p\n\n## Brainstorm\n- (none)\n\n## Links\n- x.md - why\n' > "$T/body2.md"
out="$(LITOPYS_NOW="2026-09-21T13:00:00Z" bash "$CLI" distill record --journal "$P/.litopys/raw/$SID.md" \
  --body "$T/body2.md" --force 2>&1)"
eq "--force exits 0" "0" "$?"
cat "$REC" | expect "--force rewrote the record" "# Second pass title"
eq "--force appended a second chronicle line" "2" "$(lines "$CHRON")"

# --- P4: bad input -> exit 2, nothing written, journal untouched ---------------------------
badcase() { # badcase <label> <extra args...>   (journal + a project of its own)
  local label="$1"; shift
  local b; b="$(newproj "bad-$(printf '%s' "$label" | tr -c 'a-z0-9' '-')")"
  export CLAUDE_PROJECT_DIR="$b"
  local rc
  LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$b/.litopys/raw/$SID.md" "$@" >/dev/null 2>&1
  rc=$?
  eq "$label exits 2" "2" "$rc"
  no_file "$label writes no record" "$b/docs/chronicle"
  no_file "$label writes no cost row" "$b/.litopys/distill.jsonl"
  if [ -f "$b/.litopys/raw/$SID.md" ]; then echo "  ok    $label leaves the journal queued"
  else bad "$label moved the journal"; fi
}

printf '# T\n\n## Decisions\n- d\n\n## Brainstorm\n- b\n\n## Links\n- x\n' > "$T/no-problems.md"
printf '# T\n\n## Problems\n- p\n\n## Decisions\n- d\n\n## Brainstorm\n- b\n\n## Links\n- x\n' > "$T/out-of-order.md"
badcase "missing section" --body "$T/no-problems.md"
badcase "sections out of order" --body "$T/out-of-order.md"
badcase "source other" --body "$FIX/distill-body.md" --source other

E="$(newproj bad-stdin)"
export CLAUDE_PROJECT_DIR="$E"
printf '' | LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$E/.litopys/raw/$SID.md" --body - >/dev/null 2>&1
eq "empty stdin body exits 2" "2" "$?"
no_file "empty stdin body writes no record" "$E/docs/chronicle"
if [ -f "$E/.litopys/raw/$SID.md" ]; then echo "  ok    empty stdin body leaves the journal queued"
else bad "empty stdin body moved the journal"; fi

N="$T/no-sid"
mkdir -p "$N/.litopys/raw"
grep -v '^session_id:' "$FIX/raw-resume.md" > "$N/.litopys/raw/$SID.md"
export CLAUDE_PROJECT_DIR="$N"
err="$(LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$N/.litopys/raw/$SID.md" \
  --body "$FIX/distill-body.md" 2>&1 >/dev/null)"
eq "journal without session_id exits 2" "2" "$?"
printf '%s' "$err" | expect "stderr names the missing key" "session_id"
no_file "no session_id writes no record" "$N/docs/chronicle"
if [ -f "$N/.litopys/raw/$SID.md" ]; then echo "  ok    no session_id leaves the journal queued"
else bad "no session_id moved the journal"; fi

M="$T/missing-journal"
mkdir -p "$M"
export CLAUDE_PROJECT_DIR="$M"
LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$M/nope.md" --body "$FIX/distill-body.md" >/dev/null 2>&1
eq "missing journal exits 2" "2" "$?"
no_file "missing journal writes nothing" "$M/docs"

# --- P5: the verb itself ---------------------------------------------------------------------
err="$(bash "$CLI" distill 2>&1 >/dev/null)"
eq "distill with no verb exits 2" "2" "$?"
printf '%s' "$err" | expect "no verb prints usage" "litopys distill record"
err="$(bash "$CLI" distill wat 2>&1 >/dev/null)"
eq "unknown verb exits 2" "2" "$?"
printf '%s' "$err" | expect "unknown verb is named" "wat"

if [ -s "$FAILED" ]; then
  echo "distill.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "distill.test.sh: all green"
exit 0
