#!/usr/bin/env bash
# Stand-in for the `claude` binary, pointed at by LITOPYS_CLAUDE in tests/bench.test.sh.
# Prints the canned `--output-format json` payload that matches the question in its last
# argument, so the suite exercises `bench` without ever calling a model.
#
# The usage blocks mirror the shape a live `claude -p --output-format json` returns (probed
# 2026-09-21): a tiny uncached `input_tokens` beside large `cache_creation_input_tokens` /
# `cache_read_input_tokens`, plus a per-model `modelUsage` map in camelCase
# (`inputTokens`, `outputTokens`, `cacheReadInputTokens`, `cacheCreationInputTokens`).
#
# LITOPYS_STUB_IS_ERROR=1 makes every call answer with `"is_error":true` and exit 0 - the
# shape a failed API call takes when the CLI itself succeeded.
#
# LITOPYS_STUB_UNPARSABLE=1 makes every call print plain, non-JSON text and exit 0 - the shape
# a broken `--output-format json` response takes when jq cannot parse it at all.
#
# Logs every invocation (cwd + argv, one line per field) to $LITOPYS_STUB_LOG when set,
# which is how the test asserts the flags and cwd of the real call.
set -u

q=""
for a in "$@"; do q="$a"; done

if [ -n "${LITOPYS_STUB_LOG:-}" ]; then
  { printf 'call cwd=%s\n' "$PWD"; for a in "$@"; do printf 'arg %s\n' "$a"; done; } >> "$LITOPYS_STUB_LOG"
fi

if [ "${LITOPYS_STUB_UNPARSABLE:-0}" = "1" ]; then
  # Exit 0 with stdout that is not JSON at all - jq must fail cleanly on this, not on a merely
  # unexpected shape.
  echo "this is not json"
  exit 0
fi

if [ "${LITOPYS_STUB_IS_ERROR:-0}" = "1" ]; then
  # Exit 0, but the payload says the call failed: the keyphrases and refs of every question
  # are deliberately present in `result` - a row that scores them would be scoring an error.
  cat <<'J'
{"type":"result","is_error":true,"result":"API Error: 500 upstream connect error\nv1.2.3 ADR-042 gamma-cleaner delta-fix epsilon-2026 docs/alpha.md a1b2c3d docs/epsilon.md e5f6a7b","usage":{"input_tokens":7,"cache_creation_input_tokens":900,"cache_read_input_tokens":100,"output_tokens":11},"total_cost_usd":0.004}
J
  exit 0
fi

case "$q" in
  *alpha*)
    # hit (case differs from the keyphrase) + both refs; cache-inclusive tokens_in = 51616.
    # Every field also carries its camelCase twin at a different value - snake_case wins per
    # field, so the sum must stay 51616/678, never double-counted.
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** The alpha gate shipped in V1.2.3.\n**Refs:**\n- docs/alpha.md - the gate\n- a1b2c3d - the commit\n**Confidence:** high","usage":{"input_tokens":12,"cache_creation_input_tokens":27542,"cache_read_input_tokens":24062,"output_tokens":678,"inputTokens":999,"cacheCreationInputTokens":999,"cacheReadInputTokens":999,"outputTokens":999},"total_cost_usd":0.0123}
J
    ;;
  *beta*)
    # hit + one ref of two; top-level usage is all-zero, so the per-model map is the source:
    # tokens_in = (5+1200+800) + (1+300+50) = 2356, tokens_out = 100 + 20 = 120
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** ADR-042 decided it.\n**Refs:**\n- docs/adr/042-beta.md - the decision\n**Confidence:** medium","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0},"modelUsage":{"claude-sonnet-4-5":{"inputTokens":5,"cacheCreationInputTokens":1200,"cacheReadInputTokens":800,"outputTokens":100},"claude-haiku-4-5":{"inputTokens":1,"cacheCreationInputTokens":300,"cacheReadInputTokens":50,"outputTokens":20}},"total_cost_usd":0.002}
J
    ;;
  *gamma*)
    # miss: neither the keyphrase nor the ref appears; tokens_in = 3+1500+0 = 1503
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** Nothing in this project's history answers that.\n**Refs:**\n- none\n**Confidence:** low","usage":{"input_tokens":3,"cache_creation_input_tokens":1500,"cache_read_input_tokens":0,"output_tokens":40},"total_cost_usd":0.001}
J
    ;;
  *delta*)
    echo "stub: simulated claude failure" >&2
    echo "more stderr that must not reach the row" >&2
    exit 1
    ;;
  *)
    # hit + both refs, but no usage block of either kind and no cost
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** epsilon-2026.\n**Refs:**\n- docs/epsilon.md - the note\n- e5f6a7b - the commit\n**Confidence:** high"}
J
    ;;
esac
exit 0
