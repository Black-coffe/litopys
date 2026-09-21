<!-- seat: haiku · model: claude-sonnet-5 · round: 3 · head: 2ed02e3 · pack: ac0d2bda0834 · attempt: 1 · recorded: 2026-09-21T14:14:43Z -->
COUNCIL: litopys-phase-0-1 · round 3 · seat haiku
MODEL: claude-sonnet-5
COURT: E:/Projects/litopys/.vulyk/court/litopys-phase-0-1/round-3
VERDICT: RED
ASSUMED CONFIG: single machine, Windows Git Bash primary, Browser MCP: none
RAN: claude plugin validate . --strict; claude --plugin-dir . -p "/litopys:recall ..." (default model and --model sonnet); bin/litopys append/bench/--version/help (in scratch git repos, never inside COURT); hooks/session-start.sh and hooks/raw-journal.sh with sample JSON payloads on stdin
PATH: `claude --plugin-dir .` loads the plugin; `/litopys:recall <q>` answers; CLI `bin/litopys append|bench` run standalone against a scratch project (COURT itself never written to)
ASK 1: GREEN - plugin skeleton loads - run: `claude --plugin-dir . -p "/litopys:recall ..."` saw: plugin listed and skill answered; `claude plugin validate . --strict` only warns (root CLAUDE.md not loaded as context), does not block loading
ASK 2: GREEN - append idempotent, no model - run: `bin/litopys append --kind note --ref x --note y` twice, same ts/kind/ref saw: file gains exactly one line both times (stdout echoes the line each call, file itself deduped); `--version`/`help` work
ASK 3: RED - recall answers with Answer/Refs/Confidence in correct search-order style (git log, chronicle, brief), but the "(sonnet)" subagent-model guarantee does not hold for a bare `/litopys:recall` call - run: same command with default top model vs `--model sonnet` saw: `modelUsage` was `claude-opus-5` in the first run and `claude-sonnet-5` in the second, i.e. the fork inherits the caller's session model rather than the `model: sonnet` set in `agents/recall.md`
ASK 4: GREEN - `bin/litopys bench` - run: bench against a scratch repo with a 5-question `golden-questions.md` saw: `.litopys/baseline.jsonl` with one JSON row per question (hit, refs_matched, tokens_in/out, cost_usd, seconds, model); bench itself pins `--model sonnet` explicitly, compensating for the Ask-3 gap
ASK 5: GREEN - hooks - run: fed sample JSON to `raw-journal.sh prompt|stop|end` and `session-start.sh` saw: `.litopys/raw/<sid>.md` with frontmatter + `## user`/`## assistant`/`## closed` blocks, `end` completes in ~0.3s; SessionStart prints exactly 5 `[litopys]` lines; `.litopys/.gitignore` auto-written with `*`
ASK 6: N/A - why: environment: COURT's `docs/specs/<slug>/` is reduced to `brief.md` per this court's own contract, so `docs/specs/litopys-phase-0-1/recon/raw-vs-export.md` is not present to inspect here, and reproducing a real ≥100k-token VULYK session is outside a black-box client path
ASK 7: RED - constraints - run: grepped hooks/bin for `claude -p`/model calls (none, GREEN); ran append with a fake API-key note through `scripts/redact.sh` (masked to `[VULYK:REDACTED]`, GREEN); no CLAUDE.md writes observed (GREEN) - but "sonnet only" fails for direct `/litopys:recall` use per ASK 3's evidence, so the constraint as a whole does not hold outside `bin/litopys bench`
UNASKED: `claude plugin validate . --strict` fails on this repo because its own root `CLAUDE.md` (the VULYK constitution, not plugin content) is picked up by the plugin validator; not one of the Asks but would surface on a real `/vulyk-ship` build-check run
BREACH: none
