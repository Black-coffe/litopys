#!/usr/bin/env bash
# Stand-in for the `claude` binary, pointed at by LITOPYS_CLAUDE in tests/bench.test.sh.
# Prints the canned `--output-format json` payload that matches the question in its last
# argument, so the suite exercises `bench` without ever calling a model.
#
# Logs every invocation (cwd + argv, one line per field) to $LITOPYS_STUB_LOG when set,
# which is how the test asserts the flags and cwd of the real call.
set -u

q=""
for a in "$@"; do q="$a"; done

if [ -n "${LITOPYS_STUB_LOG:-}" ]; then
  { printf 'call cwd=%s\n' "$PWD"; for a in "$@"; do printf 'arg %s\n' "$a"; done; } >> "$LITOPYS_STUB_LOG"
fi

case "$q" in
  *alpha*)
    # hit (case differs from the keyphrase) + both refs
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** The alpha gate shipped in V1.2.3.\n**Refs:**\n- docs/alpha.md - the gate\n- a1b2c3d - the commit\n**Confidence:** high","usage":{"input_tokens":12345,"output_tokens":678},"total_cost_usd":0.0123}
J
    ;;
  *beta*)
    # hit + one ref of two
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** ADR-042 decided it.\n**Refs:**\n- docs/adr/042-beta.md - the decision\n**Confidence:** medium","usage":{"input_tokens":2000,"output_tokens":100},"total_cost_usd":0.002}
J
    ;;
  *gamma*)
    # miss: neither the keyphrase nor the ref appears
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** Nothing in this project's history answers that.\n**Refs:**\n- none\n**Confidence:** low","usage":{"input_tokens":1500,"output_tokens":40},"total_cost_usd":0.001}
J
    ;;
  *delta*)
    echo "stub: simulated claude failure" >&2
    echo "more stderr that must not reach the row" >&2
    exit 1
    ;;
  *)
    # hit + both refs, but no usage block and no cost
    cat <<'J'
{"type":"result","is_error":false,"result":"**Answer:** epsilon-2026.\n**Refs:**\n- docs/epsilon.md - the note\n- e5f6a7b - the commit\n**Confidence:** high"}
J
    ;;
esac
exit 0
