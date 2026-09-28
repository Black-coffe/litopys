# Recon: litopys write paths, git touch points, micro-defects

Written by the Queen from the one `drone-scout` report of 2026-09-28 (scouts have no Write tool).
Base: v0.2.1 on `main` (0ea23eb + docs). Line numbers are the scout's, against that base.

## Write paths in a host project (section A, condensed)

| Path | Writer | Self-ignore ensured by that writer | Redacted | Tracked by design (0.2.1) |
|---|---|---|---|---|
| `docs/chronicle/YYYY-MM.md` | `cmd_append` | n/a | `--ref`, `--note` | yes |
| `docs/chronicle/sessions/<date>-<sid8>.md` | `distill_record` | n/a | whole record, but a failing filter fell back to the unfiltered text | yes |
| `.litopys/raw/<sid>.md` | `hooks/raw-journal.sh` | on create only, failure unchecked | no (by design) | no |
| `.litopys/baseline.jsonl` | `cmd_bench` | yes | no | no |
| `.litopys/raw/done/`, `raw/skipped/` | `distill record` / `next` | yes | no | no |
| `.litopys/distill.lock`, `distill.paths`, `distill.jsonl`, `.finish-stderr`, `distill-<sid8>.body.md` | `next`, `record`, `finish`, the distiller agent | no - relied on an earlier writer | no | no |

The host's own `.gitignore` was never written (ADR-004). Only `distill finish` mutated the index
(`git add -- <manifest>`, pathspec-limited `git commit`).

## Micro-defects (section D) - the list Ask 3 is judged against

| # | Defect (scout's words, condensed) | Status in this spec |
|---|---|---|
| 1 | raw-journal.sh:70 - a failed `.gitignore` write is ignored and the unredacted journal still written | fixed, story 01 (fails closed, checked on every block) |
| 2 | bin/litopys:591-596 - a failing redactor writes the unredacted record to a tracked path | fixed, story 02 (exit 2, journal stays queued) |
| 3 | plugin.json, marketplace.json, README - "written without a model call" stale, "plus a wiki" has no skill | fixed, story 03 |
| 4 | distiller.md:52, CHANGELOG:17 - "commits `docs/chronicle/`" wrong (pathspec manifest) | fixed, story 01 |
| 5 | distiller.md:52-53 - finish prints `committed <sha7>`, the shape wants the bare sha | fixed, story 01 |
| 6 | skills/distill/SKILL.md:31 - `nothing pending` missing from the Commit line | fixed, story 01 |
| 7 | ensure-line duplicated across writers | fixed, story 01 (`ensure_scratch`) |
| 8 | bin/litopys:777, :780 - GNU-only `date -d` / `stat -c`, BSD queue order silently wrong | fixed, story 02 (ISO text key, `date -r`) |
| 9 | distiller.md:5, SKILL.md:6 - unrestricted Bash vs "no git"; recall.md claims no write tool | recall.md claim fixed, story 02; Bash scoping out (agent `tools:` pattern syntax unverified) |
| 10 | session-start.sh:41 - `golden-questions.md` counted as a chronicle file | fixed, story 02 |
| 11 | bin/litopys:437-439 - `json_str` escapes only `\` and `"` | fixed, story 02 + repair round 1 (bash 3.2-5.2) |
| 12 | bin/litopys:548-554 - `rdate` / `sid8` from unsanitised frontmatter form the record path | fixed, story 02 (`record_rel`) |
| 13 | bin/litopys:693-699 - stale-lock reclaim check-then-rm race | fixed, story 02 + repair round 1 |
| 14 | memory/map/litopys-plugin.md:40 - version 0.2.0 | out - the map is drone-docs' job at ship |
| 15 | tests/distill.test.sh:312, :320, :419 - GNU `touch -d` | fixed, story 02 (`touch -t`) |

Also named by the scout and taken: six stale `.gitkeep` files (story 03). Named and left out: the
hooks-vs-CLI root divergence for a session started in a subdirectory, and the whole repository
shipping as the plugin payload (no leak: Claude Code loads only plugin components).

## Public-repo surface (section E)

No `C:\Users`, `@gmail`, real `ghp_`/`AKIA`/`sk-` tokens in the files scanned; the only identity
hits are the intended author fields (`plugin.json`, `LICENSE`) and owner names in spec paperwork.
The fake secrets in `tests/` are deliberate fixtures.
