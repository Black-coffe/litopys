#!/usr/bin/env bash
# Secret redaction - deterministic stdin->stdout filter, no model, no tokens.
#
#   Usage: some-writer | scripts/redact.sh > file
#
# VULYK's scripts/redact.sh, copied verbatim below this header: masks well-known
# credential shapes before transcript-derived text is written to disk. Callers in
# this plugin: `bin/litopys append` (--note and --ref, C3) and `bin/litopys distill
# record` (the whole session record, C11) - everything litopys puts into git.
#
# This copy is the fallback, not the authority: the host project's own
# scripts/redact.sh wins whenever it exists, then ${CLAUDE_PLUGIN_ROOT}/scripts/
# redact.sh, then this file next to bin/ (C16). Keep the body byte-identical to
# VULYK's, mask [VULYK:REDACTED] included - if you extend the pattern list there,
# re-copy here.
#
# This is the only script here that transforms instead of reports. It still never
# blocks: if the tools are missing or the sed dialect rejects the expressions, it
# degrades to `cat` (the text passes unredacted) because eating a record entirely
# would be a silent-loss path of its own. Exit status is always 0.
set -u

MASK='[VULYK:REDACTED]'

# Case variants spelled out instead of sed's GNU-only `I` flag - BSD sed must not choke.
KEYWORDS='password|PASSWORD|Password|passwd|PASSWD|secret|SECRET|Secret|api[_-]?key|API[_-]?KEY|apikey|APIKEY|access[_-]?key|ACCESS[_-]?KEY|auth[_-]?token|AUTH[_-]?TOKEN|client[_-]?secret|CLIENT[_-]?SECRET|private[_-]?key|PRIVATE[_-]?KEY'

SED_ARGS=( -E
  -e "s|AKIA[0-9A-Z]{16}|$MASK|g"
  -e "s|ASIA[0-9A-Z]{16}|$MASK|g"
  -e "s|gh[pousr]_[A-Za-z0-9]{20,}|$MASK|g"
  -e "s|github_pat_[A-Za-z0-9_]{22,}|$MASK|g"
  -e "s|xox[baprs]-[A-Za-z0-9-]{10,}|$MASK|g"
  -e "s|sk-[A-Za-z0-9_-]{20,}|$MASK|g"
  -e "s|AIza[0-9A-Za-z_-]{35}|$MASK|g"
  -e "s|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}|$MASK|g"
  -e "s|[Bb]earer[[:space:]]+[A-Za-z0-9._~+/-]{16,}=*|Bearer $MASK|g"
  -e "s#(://)[^/[:space:]:@]+:[^/[:space:]@]+@#\1$MASK@#g"
  -e "s#([\"']?[A-Za-z0-9_-]*($KEYWORDS)[A-Za-z0-9_-]*[\"']?[[:space:]]*[=:][[:space:]]*)[\"']?[^\"'[:space:]]{6,}[\"']?#\1$MASK#g"
)

# Degrade to cat unless every tool is present AND this sed dialect accepts the script.
if ! command -v sed >/dev/null 2>&1 || ! command -v awk >/dev/null 2>&1 \
   || ! printf '' | sed "${SED_ARGS[@]}" >/dev/null 2>&1; then
  cat
  exit 0
fi

# Pass 1 (awk): PEM-style private key blocks - multi-line, sed can't span lines.
# Pass 2 (sed): single-line token shapes and key=value assignments.
awk -v mask="$MASK" '
  /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/ { inkey=1; print mask; next }
  inkey && /-----END [A-Z0-9 ]*PRIVATE KEY-----/ { inkey=0; next }
  inkey { next }
  { print }
' | sed "${SED_ARGS[@]}"

exit 0
