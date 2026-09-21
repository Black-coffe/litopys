# Codebase map

One file per module, written by drone-scout, refreshed by /vulyk-map, consumed by everyone
who must NOT read the whole codebase. Format = the scout report format (purpose, entry points,
key types, dependencies, gotchas) + a `last-verified: YYYY-MM-DD` line. Cap ~80 lines per file:
a map is an index into the territory, not a copy of it.

- `agents-and-commands.md` - VULYK framework: agent castes and `/vulyk-*` command entry points.
- `cycle.md` - VULYK framework: the build->council->repair state contract (`scripts/cycle.sh`).
- `scripts.md` - VULYK framework: every deterministic gate/helper under `scripts/`.
- `litopys-plugin.md` - the litopys plugin itself: CLI (`bin/litopys`), hooks, the
  `/litopys:recall` skill/agent pair, tests/fixtures, phase-0 baseline. Format reference:
  `docs/wiki/chronicle-format.md`.
