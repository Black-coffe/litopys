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

mkjournal() { # mkjournal <path> <sid> <started> <first-user-line> <closed|open>
  local path="$1" sid="$2" started="$3" userline="$4" trailer="${5:-closed}"
  {
    printf -- '---\n'
    printf 'litopys: raw\nversion: 1\n'
    printf 'session_id: %s\n' "$sid"
    printf 'started: %s\n' "$started"
    printf 'cwd: /host/project\nbranch: main\n'
    printf -- '---\n\n'
    printf '## user · %s\n%s\n\n' "$started" "$userline"
    if [ "$trailer" = "closed" ]; then
      printf '## assistant · %s\nok\n\n' "$started"
      printf '## closed · %s · other\n' "$started"
    fi
  } > "$path"
}

# --- fixtures are what the story says they are --------------------------------------------
cat "$FIX/raw-resume.md" | expect "fixture has a mid-file closed marker" "## closed · 2026-09-20T09:40:00Z"
cat "$FIX/raw-resume.md" | expect "fixture resumes past it" "## user · 2026-09-20T10:02:11Z"
cat "$FIX/raw-resume.md" | expect "fixture has a compact block" "## compact · 2026-09-20T10:31:00Z · auto"
cat "$FIX/raw-resume.md" | expect "fixture ends closed" "## closed · 2026-09-20T11:05:09Z"
cat "$FIX/raw-resume.md" | expect "fixture carries an sk- string" "$SECRET"
cat "$FIX/distill-body.md" | expect "body fixture has a title" "# Resume and compaction survive one journal"
cat "$FIX/distill-body.md" | expect "body fixture carries a ghp_ token" "$TOKEN"
cat "$FIX/raw-bench.md" | expect "bench fixture's first user line is /litopys:recall" "/litopys:recall what is"
cat "$FIX/raw-bench.md" | expect "bench fixture ends closed" "## closed"
for f in "$FIX/raw-resume.md" "$FIX/distill-body.md" "$FIX/raw-bench.md" "$CLI" "$SRC/tests/distill.test.sh" "$SRC/scripts/redact.sh"; do
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

# --- distill next (C12): lock, skip rule, eligibility, cap N=3 -----------------------------
unset CLAUDE_PROJECT_DIR

# N1: five journals - two bench (recall/distill), three normal, distinct started, out-of-order
# filenames - prints the three normal paths oldest-first by started, skip+lock counts, both
# bench files moved.
Q1="$T/n1-queue"
mkdir -p "$Q1/.litopys/raw"
mkjournal "$Q1/.litopys/raw/z-first.md" "n1z1n1z1-1111-2222-3333-444455556666" "2026-09-10T08:00:00Z" "do first" closed
mkjournal "$Q1/.litopys/raw/a-second.md" "n1a2n1a2-1111-2222-3333-444455556666" "2026-09-12T08:00:00Z" "do second" closed
mkjournal "$Q1/.litopys/raw/m-third.md" "n1m3n1m3-1111-2222-3333-444455556666" "2026-09-14T08:00:00Z" "do third" closed
cp "$FIX/raw-bench.md" "$Q1/.litopys/raw/bench-a.md"
mkjournal "$Q1/.litopys/raw/bench-b.md" "n1bbn1bb-1111-2222-3333-444455556666" "2026-09-11T08:00:00Z" \
  "/litopys:distill record --journal x --body y" closed
export CLAUDE_PROJECT_DIR="$Q1"
out="$(bash "$CLI" distill next 2>"$T/n1.err")"; rc=$?
eq "N1 distill next exits 0" "0" "$rc"
exp="$Q1/.litopys/raw/z-first.md
$Q1/.litopys/raw/a-second.md
$Q1/.litopys/raw/m-third.md"
eq "N1 prints the three normal paths oldest-first by started, not filename" "$exp" "$out"
eq "N1 stderr: skipped 2 pending 3 selected 3" "skipped 2 · pending 3 · selected 3" "$(cat "$T/n1.err")"
if [ -f "$Q1/.litopys/raw/skipped/bench-a.md" ] && [ -f "$Q1/.litopys/raw/skipped/bench-b.md" ]; then
  echo "  ok    N1 both bench journals moved to skipped/"
else bad "N1 bench journals not both in skipped/"; fi
if [ -f "$Q1/.litopys/distill.lock/owner" ]; then echo "  ok    N1 lock owner file exists"
else bad "N1 no lock owner file"; fi

# N2: --max 1 vs the default cap on four eligible journals
mk4() { # mk4 <dir> - four eligible normal journals with distinct started
  mkdir -p "$1/.litopys/raw"
  mkjournal "$1/.litopys/raw/j1.md" "n2j1n2j1-1111-2222-3333-444455556666" "2026-09-01T08:00:00Z" "one" closed
  mkjournal "$1/.litopys/raw/j2.md" "n2j2n2j2-1111-2222-3333-444455556666" "2026-09-02T08:00:00Z" "two" closed
  mkjournal "$1/.litopys/raw/j3.md" "n2j3n2j3-1111-2222-3333-444455556666" "2026-09-03T08:00:00Z" "three" closed
  mkjournal "$1/.litopys/raw/j4.md" "n2j4n2j4-1111-2222-3333-444455556666" "2026-09-04T08:00:00Z" "four" closed
}
Q2="$T/n2-max1"; mk4 "$Q2"
export CLAUDE_PROJECT_DIR="$Q2"
out="$(bash "$CLI" distill next --max 1 2>"$T/n2.err")"
eq "N2 --max 1 prints one path" "$Q2/.litopys/raw/j1.md" "$out"
eq "N2 --max 1 stderr: pending 4 selected 1" "skipped 0 · pending 4 · selected 1" "$(cat "$T/n2.err")"

Q3="$T/n2-cap"; mk4 "$Q3"
export CLAUDE_PROJECT_DIR="$Q3"
out="$(bash "$CLI" distill next 2>"$T/n3.err")"
exp="$Q3/.litopys/raw/j1.md
$Q3/.litopys/raw/j2.md
$Q3/.litopys/raw/j3.md"
eq "N2 default cap prints three of four eligible" "$exp" "$out"
eq "N2 default cap stderr: pending 4 selected 3" "skipped 0 · pending 4 · selected 3" "$(cat "$T/n3.err")"

# N3: an open session (last header ## user) is pending, not printed, until its mtime ages past
# 60 minutes; a journal with no ## user block at all is treated as normal (not skipped).
Q4="$T/n4-open"
mkdir -p "$Q4/.litopys/raw"
mkjournal "$Q4/.litopys/raw/open.md" "n4open01-1111-2222-3333-444455556666" "2026-09-05T08:00:00Z" "still going" open
printf -- '---\nlitopys: raw\nversion: 1\nsession_id: n4nouser1-1111-2222-3333-444455556666\nstarted: 2026-09-05T08:00:00Z\ncwd: /host/project\nbranch: main\n---\n\n## closed · 2026-09-05T08:10:00Z · other\n' \
  > "$Q4/.litopys/raw/nouser.md"
export CLAUDE_PROJECT_DIR="$Q4"
out="$(bash "$CLI" distill next 2>"$T/n4.err")"
eq "N3 fresh open session withheld; user-less journal is normal and eligible" \
  "$Q4/.litopys/raw/nouser.md" "$out"
eq "N3 stderr: pending 2 selected 1" "skipped 0 · pending 2 · selected 1" "$(cat "$T/n4.err")"
if [ -f "$Q4/.litopys/raw/open.md" ]; then echo "  ok    N3 open-session journal untouched"
else bad "N3 open-session journal moved"; fi
rm -rf "$Q4/.litopys/distill.lock"
touch -d '61 minutes ago' "$Q4/.litopys/raw/open.md"
out2="$(bash "$CLI" distill next 2>/dev/null)"
printf '%s' "$out2" | expect "N3 open session printed once its mtime ages past 60 minutes" "open.md"

# N4: a mid-file ## closed followed by more blocks, ending in a final ## closed, is eligible
# and printed once - one file, one session (C13).
Q5="$T/n5-resume"
mkdir -p "$Q5/.litopys/raw"
cp "$FIX/raw-resume.md" "$Q5/.litopys/raw/$SID.md"
export CLAUDE_PROJECT_DIR="$Q5"
out="$(bash "$CLI" distill next 2>"$T/n5.err")"
eq "N4 resumed-then-closed journal is eligible and printed once" "$Q5/.litopys/raw/$SID.md" "$out"
eq "N4 stderr: pending 1 selected 1" "skipped 0 · pending 1 · selected 1" "$(cat "$T/n5.err")"

# N5: no top-level journals -> exit 0, nothing printed, zero counts, no lock left behind.
Q6="$T/n6-empty"
mkdir -p "$Q6"
export CLAUDE_PROJECT_DIR="$Q6"
out="$(bash "$CLI" distill next 2>"$T/n6.err")"; rc=$?
eq "N5 empty project exits 0" "0" "$rc"
eq "N5 empty project stdout empty" "" "$out"
eq "N5 empty project stderr all zero" "skipped 0 · pending 0 · selected 0" "$(cat "$T/n6.err")"
no_file "N5 empty project leaves no lock" "$Q6/.litopys/distill.lock"

# N6: only skippable journals -> moved, then behaves like the empty case.
Q7="$T/n7-skiponly"
mkdir -p "$Q7/.litopys/raw"
cp "$FIX/raw-bench.md" "$Q7/.litopys/raw/bench-only.md"
export CLAUDE_PROJECT_DIR="$Q7"
out="$(bash "$CLI" distill next 2>"$T/n7.err")"
eq "N6 skip-only project stdout empty" "" "$out"
eq "N6 skip-only project stderr" "skipped 1 · pending 0 · selected 0" "$(cat "$T/n7.err")"
if [ -f "$Q7/.litopys/raw/skipped/bench-only.md" ]; then echo "  ok    N6 skip-only journal moved"
else bad "N6 skip-only journal not moved"; fi
no_file "N6 skip-only project leaves no lock" "$Q7/.litopys/distill.lock"

# N7: a fresh lock refuses a second run; a 31-minute-old lock is reclaimed.
Q9="$T/n8-lock"
mkdir -p "$Q9/.litopys/raw"
mkjournal "$Q9/.litopys/raw/lk.md" "n8lkn8lk-1111-2222-3333-444455556666" "2026-09-06T08:00:00Z" "lock test" closed
export CLAUDE_PROJECT_DIR="$Q9"
out1="$(bash "$CLI" distill next 2>/dev/null)"
eq "N7 first run selects the journal" "$Q9/.litopys/raw/lk.md" "$out1"
out2="$(bash "$CLI" distill next 2>"$T/n8.err")"; rc2=$?
eq "N7 second run while lock fresh exits 3" "3" "$rc2"
eq "N7 second run stdout empty" "" "$out2"
eq "N7 second run stderr is locked" "locked" "$(cat "$T/n8.err")"
if [ -f "$Q9/.litopys/raw/lk.md" ]; then echo "  ok    N7 locked run moved no file"
else bad "N7 locked run moved the journal"; fi
touch -d '31 minutes ago' "$Q9/.litopys/distill.lock"
out3="$(bash "$CLI" distill next 2>/dev/null)"
eq "N7 stale lock reclaimed, run proceeds" "$Q9/.litopys/raw/lk.md" "$out3"

# N8: idempotence with record - once record moves a printed journal to done/, next stops
# listing it.
Q8="$(newproj n9-idempotence)"
export CLAUDE_PROJECT_DIR="$Q8"
out1="$(LITOPYS_NOW="$NOW" bash "$CLI" distill next 2>/dev/null)"
printf '%s' "$out1" | expect "N8 setup: next lists the queued journal" "$SID"
rm -rf "$Q8/.litopys/distill.lock"
LITOPYS_NOW="$NOW" bash "$CLI" distill record --journal "$Q8/.litopys/raw/$SID.md" \
  --body "$FIX/distill-body.md" > /dev/null 2>&1
out2="$(LITOPYS_NOW="$NOW" bash "$CLI" distill next 2>/dev/null)"
printf '%s' "$out2" | refute "N8 next no longer lists the journal record already moved to done/" "$SID"

if [ -s "$FAILED" ]; then
  echo "distill.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "distill.test.sh: all green"
exit 0
