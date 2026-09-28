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

eq "record appends both paths it wrote to the run manifest" "$REL
docs/chronicle/$MONTH.md" "$(cat "$P/.litopys/distill.paths")"

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
  no_file "$label appends nothing to the run manifest" "$b/.litopys/distill.paths"
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

# --- P6: a redactor that fails is never a passthrough -------------------------------------------
X="$T/p6-badfilter"
mkdir -p "$X/scripts" "$X/.litopys/raw"
printf 'exit 1\n' > "$X/scripts/redact.sh"
mkjournal "$X/.litopys/raw/$SID.md" "$SID" "2026-09-20T10:00:00Z" "do work" closed
err="$(CLAUDE_PROJECT_DIR="$X" LITOPYS_NOW="$NOW" bash "$CLI" distill record \
  --journal "$X/.litopys/raw/$SID.md" --body "$FIX/distill-body.md" 2>&1 >/dev/null)"
eq "P6 failing redactor exits 2" "2" "$?"
printf '%s' "$err" | expect "P6 says the redactor failed" "the redactor"
no_file "P6 no unfiltered record written" "$X/$REL"
[ -f "$X/.litopys/raw/$SID.md" ]
eq "P6 journal stays in the queue" "0" "$?"

# --- P7: journal frontmatter is data, never a path --------------------------------------------
Y="$T/p7-evil"
mkdir -p "$Y/.litopys/raw"
mkjournal "$Y/.litopys/raw/evil.md" "../../x/../y" "../../../etc" "do work" closed
out="$(CLAUDE_PROJECT_DIR="$Y" LITOPYS_NOW="$NOW" bash "$CLI" distill record \
  --journal "$Y/.litopys/raw/evil.md" --body "$FIX/distill-body.md" --model $'son\tnet\\x' 2>/dev/null)"
eq "P7 a hostile id and date still give one sanitised record path" \
  "docs/chronicle/sessions/2026-09-21-______x_.md" "$out"
[ -f "$Y/$out" ]
eq "P7 the record is inside docs/chronicle/sessions/" "0" "$?"
no_file "P7 nothing climbed out of the project" "$T/x"
tail -n 1 "$Y/.litopys/distill.jsonl" | jq -e . > /dev/null 2>&1
eq "P7 distill.jsonl row with a tab and a backslash is still valid JSON" "0" "$?"
eq "P7 the model survives the round trip" $'son\tnet\\x' "$(tail -n 1 "$Y/.litopys/distill.jsonl" | jq -r .model)"

# --- P8: json_str is valid JSON on every bash from 3.2 (stock macOS) up ------------------------
# The input travels in a file: Cygwin drops a CR handed to a child bash in argv under BASH_COMPAT.
{ sed -n '/^json_str() {/,/^}/p' "$CLI"
  printf '%s\n' 'v="$(cat "$1")"' "printf '{\"m\":\"%s\"}' \"\$(json_str \"\$v\")\""; } > "$T/js.sh"
printf 'a\\b"c\td\re\nf' > "$T/js.in"
for compat in 32 42 51 52; do
  out="$(BASH_COMPAT="$compat" bash "$T/js.sh" "$T/js.in")"
  # compared as jq's own JSON rendering: a native jq on Windows writes CRLF on `-r`
  eq "P8 json_str round-trips under BASH_COMPAT=$compat" '"a\\b\"c\td\re\nf"' \
    "$(printf '%s' "$out" | jq -c .m 2>/dev/null | tr -d '\r')"
done

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

# N3: eligibility is decided before the skip rule (review round 1, critical 1). A journal whose
# session may still be running is never moved, whatever its first user line - so the running
# /litopys:distill session's own journal stays put and its fragment is never created. A closed
# journal with no ## user block at all is skipped, not distilled.
Q4="$T/n4-open"
mkdir -p "$Q4/.litopys/raw"
mkjournal "$Q4/.litopys/raw/open.md" "n4open01-1111-2222-3333-444455556666" "2026-09-05T08:00:00Z" "still going" open
# the live distiller's own journal: first user line is the slash command, last block is
# ## assistant, mtime fresh.
printf -- '---\nlitopys: raw\nversion: 1\nsession_id: n4dist01-1111-2222-3333-444455556666\nstarted: 2026-09-05T08:00:00Z\ncwd: /host/project\nbranch: main\n---\n\n## user · 2026-09-05T08:00:00Z\n/litopys:distill\n\n## assistant · 2026-09-05T08:05:00Z\nworking\n' \
  > "$Q4/.litopys/raw/running.md"
printf -- '---\nlitopys: raw\nversion: 1\nsession_id: n4nouser1-1111-2222-3333-444455556666\nstarted: 2026-09-05T08:00:00Z\ncwd: /host/project\nbranch: main\n---\n\n## closed · 2026-09-05T08:10:00Z · other\n' \
  > "$Q4/.litopys/raw/nouser.md"
export CLAUDE_PROJECT_DIR="$Q4"
out="$(bash "$CLI" distill next 2>"$T/n4.err")"
eq "N3 nothing selected: two open journals, one user-less closed one" "" "$out"
eq "N3 stderr: skipped 1 pending 2 selected 0" "skipped 1 · pending 2 · selected 0" "$(cat "$T/n4.err")"
if [ -f "$Q4/.litopys/raw/skipped/nouser.md" ]; then echo "  ok    N3 closed user-less journal skipped"
else bad "N3 closed user-less journal not in skipped/"; fi
if [ -f "$Q4/.litopys/raw/open.md" ]; then echo "  ok    N3 open-session journal untouched"
else bad "N3 open-session journal moved"; fi
if [ -f "$Q4/.litopys/raw/running.md" ]; then echo "  ok    N3 live /litopys:distill journal left at the top level"
else bad "N3 the running distill journal was moved mid-session"; fi
rm -rf "$Q4/.litopys/distill.lock"
touch -t 202001010000 "$Q4/.litopys/raw/running.md"   # POSIX touch -t: long past 60 minutes
out2="$(bash "$CLI" distill next 2>"$T/n4b.err")"
eq "N3 aged /litopys:distill journal is skipped, never printed" "" "$out2"
eq "N3 aged distill journal stderr: skipped 1 pending 1 selected 0" \
  "skipped 1 · pending 1 · selected 0" "$(cat "$T/n4b.err")"
if [ -f "$Q4/.litopys/raw/skipped/running.md" ]; then echo "  ok    N3 aged distill journal moved to skipped/"
else bad "N3 aged distill journal not in skipped/"; fi
rm -rf "$Q4/.litopys/distill.lock"
touch -t 202001010000 "$Q4/.litopys/raw/open.md"
out3="$(bash "$CLI" distill next 2>/dev/null)"
printf '%s' "$out3" | expect "N3 open session printed once its mtime ages past 60 minutes" "open.md"

# N3b: an eligible journal whose record already exists is parked in skipped/<sid>.resumed.md -
# never re-distilled, never holding a cap slot (review round 1, major 4).
Q10="$T/n10-resumed"
RSID="fa11dead-1111-2222-3333-444455556666"
mkdir -p "$Q10/.litopys/raw" "$Q10/docs/chronicle/sessions"
printf -- '---\nlitopys: session\n---\n# already distilled\n' > "$Q10/docs/chronicle/sessions/2026-09-08-fa11dead.md"
mkjournal "$Q10/.litopys/raw/resumed.md" "$RSID" "2026-09-08T08:00:00Z" "carry on" closed
mkjournal "$Q10/.litopys/raw/other.md" "n10oth01-1111-2222-3333-444455556666" "2026-09-09T08:00:00Z" "normal" closed
export CLAUDE_PROJECT_DIR="$Q10"
out="$(bash "$CLI" distill next 2>"$T/n10.err")"
eq "N3b resumed journal not printed, the normal one is" "$Q10/.litopys/raw/other.md" "$out"
eq "N3b stderr: skipped 1 pending 1 selected 1" "skipped 1 · pending 1 · selected 1" "$(cat "$T/n10.err")"
if [ -f "$Q10/.litopys/raw/skipped/$RSID.resumed.md" ]; then echo "  ok    N3b parked as <sid>.resumed.md"
else bad "N3b no $Q10/.litopys/raw/skipped/$RSID.resumed.md"; fi
no_file "N3b resumed journal gone from the top level" "$Q10/.litopys/raw/resumed.md"
rm -rf "$Q10/.litopys/distill.lock"
printf 'FIRSTPARK\n' > "$Q10/.litopys/raw/skipped/$RSID.resumed.md"
out2="$(bash "$CLI" distill next 2>/dev/null)"
printf '%s' "$out2" | refute "N3b a following next no longer sees the resumed journal" "$RSID"
rm -rf "$Q10/.litopys/distill.lock"
mkjournal "$Q10/.litopys/raw/resumed-again.md" "$RSID" "2026-09-08T08:00:00Z" "carry on twice" closed
bash "$CLI" distill next > /dev/null 2>&1
if [ -f "$Q10/.litopys/raw/skipped/$RSID.resumed.2.md" ]; then echo "  ok    N3b a second resume gets a numeric suffix"
else bad "N3b no $RSID.resumed.2.md"; fi
cat "$Q10/.litopys/raw/skipped/$RSID.resumed.md" | expect "N3b the first parked file was not overwritten" "FIRSTPARK"

# N3c: a root carrying backslash-escape-shaped segments (a Windows path) is never passed through
# printf escape interpretation (review round 1, major 2).
Q11=""; BSROOT=""
if command -v cygpath > /dev/null 2>&1; then
  Q11="$T/n11-bs"
  mkdir -p "$Q11/.litopys/raw"
  BSROOT="$(cygpath -w "$Q11")"
else
  Q11="$T/n11-bs/\\Users\\temp"
  mkdir -p "$Q11/.litopys/raw" 2>/dev/null
  [ -d "$Q11/.litopys/raw" ] && BSROOT="$Q11"
fi
if [ -n "$BSROOT" ]; then
  mkjournal "$Q11/.litopys/raw/bs1.md" "n11bs001-1111-2222-3333-444455556666" "2026-09-07T08:00:00Z" "windows root" closed
  export CLAUDE_PROJECT_DIR="$BSROOT"
  out="$(bash "$CLI" distill next 2>"$T/n11.err")"; rc=$?
  eq "N3c backslash root exits 0" "0" "$rc"
  printf '%s' "$out" | expect "N3c backslash root prints the eligible journal" "bs1.md"
  eq "N3c backslash root stderr is exactly one line" "1" "$(grep -c . "$T/n11.err")"
  eq "N3c backslash root stderr shape" "skipped 0 · pending 1 · selected 1" "$(cat "$T/n11.err")"
else
  bad "N3c could not create a backslash-bearing root"
fi

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
touch -t 202001010000 "$Q9/.litopys/distill.lock"   # long past the 30-minute reclaim
out3="$(bash "$CLI" distill next 2>/dev/null)"
eq "N7 stale lock reclaimed, run proceeds" "$Q9/.litopys/raw/lk.md" "$out3"

# N7b: a reclaimer that moved a lock which turns out to be fresh gives it back, whole. A `find`
# shim reports the lock stale on the first look and fresh on the re-check - the race, made
# deterministic.
QL="$T/n7b-moveback"
mkdir -p "$QL/.litopys/distill.lock" "$T/shim"
printf 'holder\n' > "$QL/.litopys/distill.lock/owner"
cat > "$T/shim/find" <<'SHIM'
#!/usr/bin/env bash
n="$(cat "$FIND_COUNT" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" > "$FIND_COUNT"
[ "$n" -eq 1 ] && printf '%s\n' "$1"
exit 0
SHIM
chmod +x "$T/shim/find"
FIND_COUNT="$T/find.count" PATH="$T/shim:$PATH" CLAUDE_PROJECT_DIR="$QL" \
  bash "$CLI" distill next > /dev/null 2>&1
eq "N7b a fresh lock moved by mistake still means locked" "3" "$?"
eq "N7b the holder's lock is back, whole" "holder" "$(cat "$QL/.litopys/distill.lock/owner" 2>/dev/null)"
eq "N7b nothing left aside" "" "$(ls -d "$QL"/.litopys/distill.lock.stale.* 2>/dev/null)"

# N7c: journals without a `started` sort by file mtime (`date -r`), oldest first.
QM="$T/n7c-mtime"
mkdir -p "$QM/.litopys/raw"
mkjournal "$QM/.litopys/raw/a-newer.md" "n7cnewer-1111" "" "do work" closed
mkjournal "$QM/.litopys/raw/z-older.md" "n7colder-1111" "" "do work" closed
touch -t 202001010000 "$QM/.litopys/raw/a-newer.md"
touch -t 201901010000 "$QM/.litopys/raw/z-older.md"
out="$(CLAUDE_PROJECT_DIR="$QM" bash "$CLI" distill next 2>/dev/null | head -n 1)"
eq "N7c the older mtime comes first" "$QM/.litopys/raw/z-older.md" "$out"

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

# --- `distill finish`: the pathspec commit and the refusal list (C12/05) -------------------
# Every case runs in a throwaway `git init` repo under $T: the assertions are about what git
# recorded and what the host's index still holds, never about this repository.

newrepo() { # newrepo <name> - throwaway repo with one commit (b.txt); prints its root
  local r="$T/$1"
  mkdir -p "$r"
  git -C "$r" init -q > /dev/null 2>&1 || git init -q "$r" > /dev/null 2>&1
  git -C "$r" config user.email "t@example.com"
  git -C "$r" config user.name "Test"
  git -C "$r" config commit.gpgsign false
  git -C "$r" config core.autocrlf false
  git -C "$r" config core.hooksPath "$r/.git/hooks"
  printf 'base\n' > "$r/b.txt"
  git -C "$r" add -- b.txt > /dev/null 2>&1
  git -C "$r" commit -qm init > /dev/null 2>&1
  printf '%s\n' "$r"
}

put_record() { # put_record <root> <sid> <started> - one real record + chronicle line
  local r="$1" sid="$2" started="$3"
  mkdir -p "$r/.litopys/raw"
  mkjournal "$r/.litopys/raw/$sid.md" "$sid" "$started" "do work" closed
  CLAUDE_PROJECT_DIR="$r" LITOPYS_NOW="$NOW" bash "$CLI" distill record \
    --journal "$r/.litopys/raw/$sid.md" --body "$FIX/distill-body.md" > /dev/null 2>&1
}

outside_chronicle() { # outside_chronicle <root> - paths in HEAD that are not under docs/chronicle/
  local r="$1" f out=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in docs/chronicle/*) ;; *) out="$out $f" ;; esac
  done < <(git -C "$r" show --pretty=format: --name-only HEAD)
  printf '%s' "$out"
}

# F0 (C17): private by default - `distill record` wrote the litopys block into .gitignore, and
# `finish` commits nothing, stages nothing, releases the lock and clears the manifest.
R0="$(newrepo f0-private)"
put_record "$R0" "f0aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
mkdir -p "$R0/.litopys/distill.lock"
out="$(CLAUDE_PROJECT_DIR="$R0" bash "$CLI" distill finish 2>/dev/null)"; rc=$?
eq "F0 distill finish exits 0" "0" "$rc"
case "$out" in
  "kept local: "*) echo "  ok    F0 private by default: kept local" ;;
  *) bad "F0 expected 'kept local: ...', got '$out'" ;;
esac
eq "F0 no commit" "1" "$(git -C "$R0" rev-list --count HEAD)"
eq "F0 nothing staged" "" "$(git -C "$R0" diff --cached --name-only)"
no_file "F0 lock released" "$R0/.litopys/distill.lock"
no_file "F0 manifest cleared" "$R0/.litopys/distill.paths"
[ -f "$R0/docs/chronicle/sessions/2026-09-18-f0aaaaaa.md" ]
eq "F0 the record is on disk" "0" "$?"
git -C "$R0" check-ignore -q -- "docs/chronicle/sessions/2026-09-18-f0aaaaaa.md"
eq "F0 the record is git-ignored" "0" "$?"
eq "F0 git sees only the new .gitignore" "?? .gitignore" "$(git -C "$R0" status --porcelain)"

# F0b/F0c: `kept local` says only what git confirms.
R0b="$(newrepo f0b-overridden)"
put_record "$R0b" "f0bbbbbb-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
printf '!docs/chronicle/sessions/\n' >> "$R0b/.gitignore"
CLAUDE_PROJECT_DIR="$R0b" bash "$CLI" distill finish 2>/dev/null \
  | expect "F0b an overridden block is not reported as ignored" "kept local: records NOT git-ignored"
N0c="$T/f0c-nogit"
mkdir -p "$N0c/.litopys/raw"
mkjournal "$N0c/.litopys/raw/f0c.md" "f0cccccc-1111" "2026-09-18T08:00:00Z" "do work" closed
CLAUDE_PROJECT_DIR="$N0c" LITOPYS_NOW="$NOW" bash "$CLI" distill record \
  --journal "$N0c/.litopys/raw/f0c.md" --body "$FIX/distill-body.md" > /dev/null 2>&1
CLAUDE_PROJECT_DIR="$N0c" bash "$CLI" distill finish 2>/dev/null \
  | expect "F0c outside git it says so" "kept local: not a git repository"

# F1-F13 run with the owner's opt-in: the ADR-007 commit contract, unchanged.
export LITOPYS_TRACK_CHRONICLE=1

# F1: the happy path - only docs/chronicle/ is committed, the host's index is left alone.
R1="$(newrepo f1-happy)"
put_record "$R1" "f1aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
printf 'staged\n' > "$R1/a.txt"
git -C "$R1" add -- a.txt > /dev/null 2>&1
printf 'edited\n' >> "$R1/b.txt"
mkdir -p "$R1/.litopys/distill.lock"
BR0="$(git -C "$R1" symbolic-ref --short HEAD 2>/dev/null)"
export CLAUDE_PROJECT_DIR="$R1"
out="$(bash "$CLI" distill finish 2>"$T/f1.err")"; rc=$?
eq "F1 distill finish exits 0" "0" "$rc"
eq "F1 nothing on stderr" "" "$(cat "$T/f1.err")"
case "$out" in
  "committed "*) echo "  ok    F1 prints committed <sha7>" ;;
  *) bad "F1 expected 'committed <sha7>', got '$out'" ;;
esac
sha="${out#committed }"
eq "F1 sha is seven characters" "7" "${#sha}"
eq "F1 sha is HEAD" "$(git -C "$R1" rev-parse --short=7 HEAD)" "$sha"
eq "F1 commit touches nothing outside docs/chronicle/" "" "$(outside_chronicle "$R1")"
eq "F1 the record is in the commit" "1" \
  "$(git -C "$R1" show --pretty=format: --name-only HEAD | grep -c '^docs/chronicle/sessions/')"
eq "F1 a.txt is still staged" "a.txt" "$(git -C "$R1" diff --cached --name-only)"
eq "F1 b.txt is still modified and unstaged" "b.txt" "$(git -C "$R1" diff --name-only)"
eq "F1 branch unchanged" "$BR0" "$(git -C "$R1" symbolic-ref --short HEAD 2>/dev/null)"
eq "F1 commit message names one session" "chore(chronicle): distill 1 session(s) [litopys]" \
  "$(git -C "$R1" log -1 --pretty=%s)"
no_file "F1 lock released" "$R1/.litopys/distill.lock"

# F1b: run it again with no lock present - idempotent, prints normally, creates no commit.
out2="$(bash "$CLI" distill finish 2>/dev/null)"; rc=$?
eq "F1b second run exits 0" "0" "$rc"
eq "F1b second run has nothing to commit" "uncommitted: nothing to commit" "$out2"
eq "F1b no second commit" "2" "$(git -C "$R1" rev-list --count HEAD)"

# F2: the refusal list - each git state leaves the records in the working tree, untracked.
refuses() { # refuses <label> <root> <expected reason>
  local label="$1" r="$2" want="$3" head0 out
  head0="$(git -C "$r" rev-parse HEAD 2>/dev/null || true)"
  mkdir -p "$r/.litopys/distill.lock"
  out="$(CLAUDE_PROJECT_DIR="$r" bash "$CLI" distill finish 2>/dev/null)"; local rc=$?
  eq "$label exits 0" "0" "$rc"
  eq "$label says why" "uncommitted: $want" "$out"
  eq "$label created no commit" "$head0" "$(git -C "$r" rev-parse HEAD 2>/dev/null || true)"
  eq "$label left the record untracked" "" "$(git -C "$r" ls-files -- docs/chronicle)"
  if [ -d "$r/docs/chronicle/sessions" ]; then echo "  ok    $label record still in the working tree"
  else bad "$label lost the record"; fi
  no_file "$label released the lock" "$r/.litopys/distill.lock"
  if [ -f "$r/.litopys/distill.paths" ]; then echo "  ok    $label kept the run manifest"
  else bad "$label dropped the run manifest a later finish needs"; fi
}

R2="$(newrepo f2-detached)"
put_record "$R2" "f2aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
git -C "$R2" checkout -q --detach > /dev/null 2>&1
refuses "F2 detached HEAD" "$R2" "detached HEAD"

R3="$(newrepo f3-merge)"
put_record "$R3" "f3aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
git -C "$R3" rev-parse HEAD > "$R3/.git/MERGE_HEAD"
refuses "F3 merge in progress" "$R3" "merge in progress"

R4="$(newrepo f4-rebase)"
put_record "$R4" "f4aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
mkdir -p "$R4/.git/rebase-merge"
refuses "F4 rebase in progress" "$R4" "rebase in progress"

R5="$(newrepo f5-cherry)"
put_record "$R5" "f5aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
git -C "$R5" rev-parse HEAD > "$R5/.git/CHERRY_PICK_HEAD"
refuses "F5 cherry-pick in progress" "$R5" "cherry-pick in progress"

# F6: not a git repository at all.
R6="$T/f6-nogit"
mkdir -p "$R6"
put_record "$R6" "f6aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
mkdir -p "$R6/.litopys/distill.lock"
export CLAUDE_PROJECT_DIR="$R6"
out="$(bash "$CLI" distill finish 2>/dev/null)"; rc=$?
eq "F6 non-repo exits 0" "0" "$rc"
eq "F6 non-repo says why" "uncommitted: not a git repository" "$out"
no_file "F6 non-repo released the lock" "$R6/.litopys/distill.lock"

# F7: a repo with no docs/chronicle at all.
R7="$(newrepo f7-nothing)"
export CLAUDE_PROJECT_DIR="$R7"
eq "F7 nothing to commit" "uncommitted: nothing to commit" "$(bash "$CLI" distill finish 2>/dev/null)"
eq "F7 created no commit" "1" "$(git -C "$R7" rev-list --count HEAD)"

# F8: no git identity anywhere - git's own first complaint is the reason.
R8="$(newrepo f8-identity)"
put_record "$R8" "f8aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
git -C "$R8" config --unset user.email > /dev/null 2>&1
git -C "$R8" config --unset user.name > /dev/null 2>&1
mkdir -p "$T/emptyhome"
export CLAUDE_PROJECT_DIR="$R8"
out="$(HOME="$T/emptyhome" USERPROFILE="$T/emptyhome" GIT_CONFIG_GLOBAL="$T/emptyhome/none" \
  GIT_CONFIG_SYSTEM="$T/emptyhome/none" bash "$CLI" distill finish 2>/dev/null)"; rc=$?
eq "F8 identityless repo exits 0" "0" "$rc"
case "$out" in
  "uncommitted: nothing to commit") bad "F8 expected git's own complaint, got '$out'" ;;
  "uncommitted: "?*) echo "  ok    F8 reports git's first stderr line: $out" ;;
  *) bad "F8 expected 'uncommitted: <git error>', got '$out'" ;;
esac
eq "F8 created no commit" "1" "$(git -C "$R8" rev-list --count HEAD)"

# F9: host commit hooks are run, never bypassed.
R9="$(newrepo f9-hook)"
put_record "$R9" "f9aaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
printf '#!/bin/sh\nexit 1\n' > "$R9/.git/hooks/pre-commit"
chmod +x "$R9/.git/hooks/pre-commit"
export CLAUDE_PROJECT_DIR="$R9"
out="$(bash "$CLI" distill finish 2>/dev/null)"; rc=$?
eq "F9 failing pre-commit hook exits 0" "0" "$rc"
case "$out" in
  "uncommitted: "?*) echo "  ok    F9 failing hook leaves the records uncommitted" ;;
  *) bad "F9 expected 'uncommitted: <reason>', got '$out'" ;;
esac
eq "F9 failing hook created no commit" "1" "$(git -C "$R9" rev-list --count HEAD)"
printf '#!/bin/sh\ntouch "$(git rev-parse --show-toplevel)/hook-ran"\nexit 0\n' > "$R9/.git/hooks/pre-commit"
chmod +x "$R9/.git/hooks/pre-commit"
out="$(bash "$CLI" distill finish 2>/dev/null)"
case "$out" in
  "committed "*) echo "  ok    F9 passing hook commits" ;;
  *) bad "F9 expected a commit with a passing hook, got '$out'" ;;
esac
if [ -f "$R9/hook-ran" ]; then echo "  ok    F9 the hook ran (not --no-verify)"
else bad "F9 the pre-commit hook was bypassed"; fi

# F10: <n> counts the session lines in this diff, not the rows in distill.jsonl.
RA="$(newrepo f10-two)"
put_record "$RA" "faaaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
put_record "$RA" "fabbbbbb-1111-2222-3333-444455556666" "2026-09-19T08:00:00Z"
export CLAUDE_PROJECT_DIR="$RA"
out="$(bash "$CLI" distill finish 2>/dev/null)"
case "$out" in "committed "*) echo "  ok    F10 two-record run commits" ;; *) bad "F10 got '$out'" ;; esac
eq "F10 message counts two sessions" "chore(chronicle): distill 2 session(s) [litopys]" \
  "$(git -C "$RA" log -1 --pretty=%s)"
eq "F10 commit touches nothing outside docs/chronicle/" "" "$(outside_chronicle "$RA")"

# F12: the commit holds only what this run wrote - an unrelated untracked file and a host edit
# to a tracked month file, both under docs/chronicle/, stay out of it (review round 1, major 3).
RB="$(newrepo f12-only-ours)"
mkdir -p "$RB/docs/chronicle"
printf '# Chronicle 2020-01\n\n- old\n' > "$RB/docs/chronicle/2020-01.md"
git -C "$RB" add -- docs/chronicle/2020-01.md > /dev/null 2>&1
git -C "$RB" commit -qm chronicle > /dev/null 2>&1
put_record "$RB" "fbaaaaaa-1111-2222-3333-444455556666" "2026-09-18T08:00:00Z"
printf 'golden\n' > "$RB/docs/chronicle/golden-questions.md"
printf -- '- host edit\n' >> "$RB/docs/chronicle/2020-01.md"
export CLAUDE_PROJECT_DIR="$RB"
out="$(bash "$CLI" distill finish 2>/dev/null)"
case "$out" in "committed "*) echo "  ok    F12 commits" ;; *) bad "F12 got '$out'" ;; esac
eq "F12 the commit holds only this run's record and month file" \
  "docs/chronicle/2026-09.md
docs/chronicle/sessions/2026-09-18-fbaaaaaa.md" \
  "$(git -C "$RB" show --pretty=format: --name-only HEAD | grep . | sort)"
eq "F12 the unrelated file under docs/chronicle/ is still untracked" "docs/chronicle/golden-questions.md" \
  "$(git -C "$RB" ls-files --others --exclude-standard -- docs/chronicle)"
eq "F12 the host edit to the tracked month file is still unstaged" "docs/chronicle/2020-01.md" \
  "$(git -C "$RB" diff --name-only)"
no_file "F12 the manifest is consumed by the commit" "$RB/.litopys/distill.paths"

# F13: <n> counts distinct record paths - a --force re-distillation of one record says one.
RC="$(newrepo f13-force)"
SIDF="fcaaaaaa-1111-2222-3333-444455556666"
put_record "$RC" "$SIDF" "2026-09-18T08:00:00Z"
mkjournal "$RC/.litopys/raw/$SIDF.md" "$SIDF" "2026-09-18T08:00:00Z" "again" closed
CLAUDE_PROJECT_DIR="$RC" LITOPYS_NOW="2026-09-21T14:00:00Z" bash "$CLI" distill record \
  --journal "$RC/.litopys/raw/$SIDF.md" --body "$FIX/distill-body.md" --force > /dev/null 2>&1
export CLAUDE_PROJECT_DIR="$RC"
out="$(bash "$CLI" distill finish 2>/dev/null)"
case "$out" in "committed "*) echo "  ok    F13 --force run commits" ;; *) bad "F13 got '$out'" ;; esac
eq "F13 a second chronicle line does not inflate <n>" "chore(chronicle): distill 1 session(s) [litopys]" \
  "$(git -C "$RC" log -1 --pretty=%s)"

# F11: argument handling - finish takes none.
eq "F11 stray argument exits 2" "2" "$(bash "$CLI" distill finish --now > /dev/null 2>&1; echo $?)"

if [ -s "$FAILED" ]; then
  echo "distill.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "distill.test.sh: all green"
exit 0
