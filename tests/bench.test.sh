#!/usr/bin/env bash
# `bin/litopys bench` - golden questions through recall into .litopys/baseline.jsonl (C1, C4, C5).
#
#   Usage: bash tests/bench.test.sh            # from the litopys repo root
#
# Never calls a model: LITOPYS_CLAUDE points at tests/fixtures/claude-stub.sh, which prints
# canned `--output-format json` payloads. Every assertion is about the row that landed in
# baseline.jsonl, the summary line, or the argv the stub was handed.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$SRC/bin/litopys"
STUB="$SRC/tests/fixtures/claude-stub.sh"
QFIX="$SRC/tests/fixtures/golden-questions.md"
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
rows() { local c; c="$(grep -c . "$1" 2>/dev/null)"; printf '%s\n' "${c:-0}"; }
field() { # field <jsonl> <q> <jq-filter>   - first row for that question
  jq -r --arg q "$2" "select(.q == \$q) | $3" "$1" 2>/dev/null | head -n 1
}

if ! command -v jq > /dev/null 2>&1; then
  echo "bench.test.sh: jq not found - bench and this test both require it"; exit 1
fi

NOW="2026-09-21T12:34:56Z"

# --- a project with the golden questions in place -----------------------------------------
P="$T/proj"
mkdir -p "$P/docs/chronicle"
cp "$QFIX" "$P/docs/chronicle/golden-questions.md"
BL="$P/.litopys/baseline.jsonl"
LOG="$T/stub.log"
export CLAUDE_PROJECT_DIR="$P"
export LITOPYS_CLAUDE="$STUB"
export LITOPYS_STUB_LOG="$LOG"

out="$(LITOPYS_NOW="$NOW" bash "$CLI" bench 2>"$T/err")"
eq "bench exits 0" "0" "$?"
printf '%s' "$out" | expect "summary line (C5)" "hits 3/5 · refs 5/8 ·"
eq "five rows" "5" "$(rows "$BL")"

# --- C1: .litopys/ ignores itself ----------------------------------------------------------
cat "$P/.litopys/.gitignore" | expect ".litopys/.gitignore self-ignores" "*"

# --- C5 row shape --------------------------------------------------------------------------
eq "row keeps the run ts"        "$NOW"   "$(field "$BL" Q1 .ts)"
eq "row names the project"       "proj"   "$(field "$BL" Q1 .project)"
eq "row carries the question"    "Which version shipped the alpha gate?" "$(field "$BL" Q1 .question)"
eq "row names the model"         "sonnet" "$(field "$BL" Q1 .model)"
eq "row carries the version"     "0.3.0"  "$(field "$BL" Q1 .litopys)"
eq "seconds is a number"         "number" "$(field "$BL" Q1 '.seconds|type')"

# Q1: the keyphrase differs in case from the answer text, both refs present
eq "Q1 hit (case-insensitive)"   "true"   "$(field "$BL" Q1 .hit)"
eq "Q1 refs_expected"            "2"      "$(field "$BL" Q1 .refs_expected)"
eq "Q1 refs_matched"             "2"      "$(field "$BL" Q1 .refs_matched)"
# tokens_in is the whole input side (12 uncached + 27542 cache-creation + 24062 cache-read),
# not the uncached slice alone - a cache-blind column reads ~0 on every real run (C5, round 1).
eq "Q1 tokens_in is cache-inclusive" "51616" "$(field "$BL" Q1 .tokens_in)"
refute_uncached="$(field "$BL" Q1 .tokens_in)"
if [ "$refute_uncached" = "12" ]; then bad "Q1 tokens_in is the uncached slice only"; fi
eq "Q1 tokens_out from usage"    "678"    "$(field "$BL" Q1 .tokens_out)"
eq "Q1 cost_usd"                 "0.0123" "$(field "$BL" Q1 .cost_usd)"
eq "Q1 has no error key"         "null"   "$(field "$BL" Q1 '.error // "null"')"
# Q1's usage object carries both spellings of every field (snake_case + a decoy camelCase) -
# the snake_case values above (51616/678) must win outright, not be added to the decoys.
eq "Q1 snake+camel same object counts once (no double count)" "51616" "$(field "$BL" Q1 .tokens_in)"

# Q2: hit, one ref of two; top-level usage is all-zero so modelUsage is summed over both models
eq "Q2 hit"                      "true"   "$(field "$BL" Q2 .hit)"
eq "Q2 refs_matched 1 of 2"      "1"      "$(field "$BL" Q2 .refs_matched)"
eq "Q2 refs_expected"            "2"      "$(field "$BL" Q2 .refs_expected)"
eq "Q2 tokens_in from modelUsage"  "2356" "$(field "$BL" Q2 .tokens_in)"
eq "Q2 tokens_out from modelUsage" "120"  "$(field "$BL" Q2 .tokens_out)"
# Explicit: top-level usage is present and all-zero, so the row falls back to modelUsage rather
# than reading zeros (Ask 9).
eq "Q2 all-zero top-level usage falls back to modelUsage" "2356" "$(field "$BL" Q2 .tokens_in)"

# Q3: miss
eq "Q3 miss"                     "false"  "$(field "$BL" Q3 .hit)"
eq "Q3 refs_matched 0"           "0"      "$(field "$BL" Q3 .refs_matched)"
eq "Q3 still counts its refs"    "1"      "$(field "$BL" Q3 .refs_expected)"
eq "Q3 tokens_in is cache-inclusive" "1503" "$(field "$BL" Q3 .tokens_in)"
eq "Q3 tokens_out from usage"    "40"     "$(field "$BL" Q3 .tokens_out)"

# Q4: the stub exits 1
eq "Q4 failed call is not a hit" "false"  "$(field "$BL" Q4 .hit)"
eq "Q4 carries the error line"   "stub: simulated claude failure" "$(field "$BL" Q4 .error)"
field "$BL" Q4 .error | refute "error is the FIRST stderr line only" "more stderr"
eq "Q4 row is still written"     "Q4"     "$(field "$BL" Q4 .q)"

# Q5: no usage block -> nulls
eq "Q5 hit"                      "true"   "$(field "$BL" Q5 .hit)"
eq "Q5 tokens_in null"           "null"   "$(field "$BL" Q5 .tokens_in)"
eq "Q5 tokens_out null"          "null"   "$(field "$BL" Q5 .tokens_out)"
eq "Q5 cost_usd null"            "null"   "$(field "$BL" Q5 .cost_usd)"
eq "Q5 refs_matched 2"           "2"      "$(field "$BL" Q5 .refs_matched)"

# --- the invocation itself (plan assumption: claude -p through the slash command) ----------
eq "one claude call per question" "5" "$(grep -c '^call cwd=' "$LOG")"
cat "$LOG" | expect "print mode"          "arg -p"
cat "$LOG" | expect "--plugin-dir"        "arg --plugin-dir"
cat "$LOG" | expect "plugin root passed"  "arg $SRC"
cat "$LOG" | expect "sonnet"              "arg sonnet"
cat "$LOG" | expect "json output"         "arg json"
cat "$LOG" | expect "slash command form"  "arg /litopys:recall Which version shipped the alpha gate?"
cat "$LOG" | expect "cwd is the project"  "call cwd=$P"

# --- a second run appends, it does not replace ---------------------------------------------
: > "$LOG"
LITOPYS_NOW="2026-09-21T13:00:00Z" bash "$CLI" bench > /dev/null 2>&1
eq "second run appends five more" "10" "$(rows "$BL")"
eq "second run keeps its own ts" "2026-09-21T13:00:00Z" \
   "$(jq -r 'select(.q == "Q1") | .ts' "$BL" | tail -n 1)"
if jq -e . "$BL" > /dev/null 2>&1; then echo "  ok    every row is valid JSON"
else bad "baseline.jsonl holds a row jq cannot parse"; fi

# --- exit 0 with "is_error":true is a failed call, not an answer (C5) ----------------------
E="$T/is-error-proj"
mkdir -p "$E/docs/chronicle"
cp "$QFIX" "$E/docs/chronicle/golden-questions.md"
EBL="$E/.litopys/baseline.jsonl"
eout="$(CLAUDE_PROJECT_DIR="$E" LITOPYS_STUB_IS_ERROR=1 LITOPYS_NOW="$NOW" bash "$CLI" bench 2>/dev/null)"
eq "is_error run still exits 0"  "0"      "$?"
eq "is_error run writes 5 rows"  "5"      "$(rows "$EBL")"
printf '%s' "$eout" | expect "is_error scores no hits" "hits 0/5 · refs 0/8 ·"
eq "is_error Q1 not a hit"       "false"  "$(field "$EBL" Q1 .hit)"
eq "is_error Q1 refs_matched 0"  "0"      "$(field "$EBL" Q1 .refs_matched)"
eq "is_error Q1 keeps refs_expected" "2"  "$(field "$EBL" Q1 .refs_expected)"
eq "is_error Q1 carries the first result line" "API Error: 500 upstream connect error" \
   "$(field "$EBL" Q1 .error)"
field "$EBL" Q1 .error | refute "is_error takes the FIRST line only" "v1.2.3"
eq "is_error row still has tokens" "1007" "$(field "$EBL" Q1 .tokens_in)"

# --- bench never reads stdin (manual mode; an open pipe must not block) --------------------
S="$T/stdin-proj"
mkdir -p "$S/docs/chronicle"
cp "$QFIX" "$S/docs/chronicle/golden-questions.md"
mkfifo "$T/fifo"
exec 9<> "$T/fifo"            # writer stays open and never writes: a read here blocks forever
( export CLAUDE_PROJECT_DIR="$S"; bash "$CLI" bench > /dev/null 2>&1 ) < "$T/fifo" &
pid=$!
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
if kill -0 "$pid" 2>/dev/null; then
  kill -9 "$pid" 2>/dev/null || true
  bad "bench blocked on an open stdin pipe (manual modes must not read stdin)"
else
  wait "$pid" 2>/dev/null || true
  echo "  ok    bench does not read stdin"
fi
exec 9>&-
eq "the stdin run still wrote its rows" "5" "$(rows "$S/.litopys/baseline.jsonl")"

# --- non-JSON stdout on an exit-0 call: scored as a miss, carries an error key (Ask 9) ------
U="$T/unparsable-proj"
mkdir -p "$U/docs/chronicle"
cp "$QFIX" "$U/docs/chronicle/golden-questions.md"
UBL="$U/.litopys/baseline.jsonl"
uout="$(CLAUDE_PROJECT_DIR="$U" LITOPYS_STUB_UNPARSABLE=1 LITOPYS_NOW="$NOW" bash "$CLI" bench 2>/dev/null)"
eq "unparsable stdout run still exits 0" "0"      "$?"
eq "unparsable stdout run writes 5 rows" "5"      "$(rows "$UBL")"
printf '%s' "$uout" | expect "unparsable stdout scores no hits" "hits 0/5 · refs 0/8 ·"
eq "unparsable Q1 not a hit"            "false"  "$(field "$UBL" Q1 .hit)"
eq "unparsable Q1 refs_matched 0"       "0"      "$(field "$UBL" Q1 .refs_matched)"
eq "unparsable Q1 tokens_in null"       "null"   "$(field "$UBL" Q1 .tokens_in)"
eq "unparsable Q1 carries the error key" "unparsable stdout" "$(field "$UBL" Q1 .error)"

# --- malformed golden questions: one stderr line, exit 2, nothing written -------------------
check_malformed() { # check_malformed <label> <file body>
  local label="$1" body="$2" M err
  M="$T/bad-$RANDOM"
  mkdir -p "$M/docs/chronicle"
  printf '%s\n' "$body" > "$M/docs/chronicle/golden-questions.md"
  err="$(CLAUDE_PROJECT_DIR="$M" bash "$CLI" bench 2>&1 > /dev/null)"
  eq "$label exits 2" "2" "$?"
  eq "$label prints exactly one stderr line" "1" "$(printf '%s\n' "$err" | grep -c .)"
  printf '%s' "$err" | expect "$label says malformed" "malformed"
  if [ -e "$M/.litopys" ]; then bad "$label wrote .litopys/ anyway"
  else echo "  ok    $label writes nothing"; fi
}
check_malformed "four questions" "$(sed '/^## Q5/,$d' "$QFIX")"
check_malformed "no refs line"   "$(grep -v '^- refs:' "$QFIX")"
check_malformed "no answer line" "$(grep -v '^- answer:' "$QFIX")"

# --- a project without golden questions ----------------------------------------------------
N="$T/no-questions"
mkdir -p "$N"
err="$(CLAUDE_PROJECT_DIR="$N" bash "$CLI" bench 2>&1 > /dev/null)"
eq "missing golden questions exits 2" "2" "$?"
printf '%s' "$err" | expect "missing file is named" "golden-questions.md"

# --- bench --delta (C15): baseline vs latest, no model call ---------------------------------
DFIX="$SRC/tests/fixtures/baseline-delta.jsonl"
NOCLAUDE="$T/no-claude.sh"
NOCLAUDE_LOG="$T/no-claude.log"
printf '#!/usr/bin/env bash\necho called >> "%s"\nexit 99\n' "$NOCLAUDE_LOG" > "$NOCLAUDE"
chmod +x "$NOCLAUDE"

D="$T/delta-proj"
mkdir -p "$D/.litopys"
cp "$DFIX" "$D/.litopys/baseline.jsonl"
dout="$(CLAUDE_PROJECT_DIR="$D" LITOPYS_CLAUDE="$NOCLAUDE" bash "$CLI" bench --delta 2>"$T/delta-err")"
eq "delta (null variant) exits 0" "0" "$?"
printf '%s' "$dout" | expect "delta null variant: hits" "hits 3/5 -> 4/5 (+1)"
printf '%s' "$dout" | expect "delta null variant: refs" "refs 6/10 -> 8/10 (+2)"
printf '%s' "$dout" | expect "delta null variant: seconds equal (+0)" "seconds 100 -> 100 (+0)"
printf '%s' "$dout" | expect "delta null variant: tokens_in null -> n/a" "tokens_in 500000 -> null (n/a)"
printf '%s' "$dout" | expect "delta null variant: tokens_out pct" "tokens_out 2500 -> 2000 (-20%)"
printf '%s' "$dout" | expect "delta null variant: cost equal (0%)" "cost_usd 0.5 -> 0.5 (0%)"
eq "delta prints exactly one line" "1" "$(printf '%s\n' "$dout" | grep -c .)"

DN="$T/delta-proj-numeric"
mkdir -p "$DN/.litopys"
sed 's/"tokens_in":null/"tokens_in":110000/' "$DFIX" > "$DN/.litopys/baseline.jsonl"
dnout="$(CLAUDE_PROJECT_DIR="$DN" LITOPYS_CLAUDE="$NOCLAUDE" bash "$CLI" bench --delta 2>/dev/null)"
eq "delta (all-numeric variant) exits 0" "0" "$?"
eq "delta (all-numeric variant) is exactly the C15 line" \
  "delta vs baseline · hits 3/5 -> 4/5 (+1) · refs 6/10 -> 8/10 (+2) · seconds 100 -> 100 (+0) · tokens_in 500000 -> 550000 (+10%) · tokens_out 2500 -> 2000 (-20%) · cost_usd 0.5 -> 0.5 (0%)" \
  "$dnout"

D9="$T/delta-proj-9rows"
mkdir -p "$D9/.litopys"
head -n 9 "$DN/.litopys/baseline.jsonl" > "$D9/.litopys/baseline.jsonl"
d9out="$(CLAUDE_PROJECT_DIR="$D9" LITOPYS_CLAUDE="$NOCLAUDE" bash "$CLI" bench --delta 2>"$T/delta9-err" > "$T/delta9-out")"
eq "delta on 9 rows exits 2" "2" "$?"
eq "delta on 9 rows prints no stdout" "0" "$(wc -c < "$T/delta9-out" | tr -d ' ')"
eq "delta on 9 rows prints exactly one stderr line" "1" "$(grep -c . "$T/delta9-err")"

if [ -e "$NOCLAUDE_LOG" ]; then bad "bench --delta called claude (LITOPYS_CLAUDE was invoked)"
else echo "  ok    bench --delta never calls claude"; fi

if [ -s "$FAILED" ]; then
  echo "bench.test.sh: FAILED - $(grep -c . "$FAILED") assertion(s)"
  exit 1
fi
echo "bench.test.sh: all green"
exit 0
