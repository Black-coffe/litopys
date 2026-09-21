# ADR-005: Redaction delegated to the host's `scripts/redact.sh` in phase 0/1, plugin fallback deferred

- Status: proposed
- Date: 2026-09-21
- Spec: docs/specs/litopys-phase-0-1

## Context
From `plan.md` `## Assumptions`:
> **Chronicle notes pass through the host's `scripts/redact.sh`** when that file exists (VULYK hosts have it), else unredacted passthrough. Golden questions (story 03) are the other git-bound text: the worker pipes the finished file through `scripts/redact.sh` (present in this repo via VULYK) before returning, so every git-bound path this phase writes passes redact (Ask 7).

From `## Descoped`:
> UNASKED (d) redaction depends on the host's `scripts/redact.sh` - true and accepted for phase 0/1 (the first consumer is VULYK, which ships it); phase 2 bundles a fallback redactor in the plugin.

## Options
1. Ship a redactor inside the plugin from phase 0, independent of any host - more upfront work, duplicates VULYK's existing `scripts/redact.sh` before a second host without one is even known.
2. Depend entirely on the host's `scripts/redact.sh` when present, unredacted passthrough otherwise; defer a plugin-native fallback to phase 2 - chosen.

## Decision
Every git-bound path the plugin writes in phase 0/1 (chronicle notes via `append`, the golden-questions file) is piped through `<root>/scripts/redact.sh` when that file exists in the host project. When it does not exist, text passes through unredacted. No redaction logic ships inside the plugin itself in this phase.

## Consequences
Phase 0/1 has no redaction guarantee for hosts that lack `scripts/redact.sh` - VULYK ships one, so the only real consumer today is covered, but a host without it gets silent unredacted passthrough. This is accepted as a known gap, not a hidden one. Phase 2 is committed to bundling a fallback redactor in the plugin so this stops being host-dependent.

## Invariants created
Every plugin code path that writes text into a host's tracked git tree (not `.litopys/`) must check for and pipe through `<root>/scripts/redact.sh` before writing, falling back to passthrough only when the script is absent.

## Revisit when
Phase 2 begins (a plugin-native fallback redactor is already committed there), or a second host project without `scripts/redact.sh` becomes a real consumer before phase 2 starts.
