---
story: correction-evidence-01
spec: correction-evidence
status: done
returned: DONE
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The journal keeps the owner's words apart from harness text

## Goal
The `prompt` hook writes only human text under `## user`. Each `<task-notification>`, `<system-reminder>`,
`<cross-session-message>` and `<pasted_content>` segment goes into its own `## notice · <ts> · <kind>` block, verbatim.
Nothing is dropped, and no model or new dependency is added.

## Requirements
> 1. журнал пишет служебные вставки (отчёты субагентов, system-reminder, сообщения других сессий, вставленный текст) отдельным блоком `## notice`, не как ваши слова

## Files
- hooks/raw-journal.sh
- tests/hooks.test.sh

## Non-goals
- Do not change `stop`, `end` or `compact`, the frontmatter, or the file layout.
- Do not strip code fences: they are the owner's content.
- Do not touch `bin/litopys` or the distiller (story 02).

## Map slice
memory/map/litopys-plugin.md: the hooks section (`raw-journal.sh`).

## Acceptance criteria
- [ ] A prompt made only of a `<task-notification>…</task-notification>` writes one `## notice · <ts> · task-notification` block and no `## user` block. This is the original case: 61 of 110 VULYK "user" blocks.
- [ ] Neighbour form: human text, then a `<pasted_content …>` segment, then more human text. This writes one `## user` block with both human parts, followed by `## notice · <ts> · pasted`.
- [ ] A `<system-reminder>` and a `<cross-session-message>` each land as their own notice kind. An unclosed tag runs to the end of the prompt, as in VULYK's BLOCKS.
- [ ] A prompt with no tags is written exactly as before, byte for byte.
- [ ] The hook still prints nothing and still exits 0 when jq is missing or the payload is malformed.

## Verification
`bash tests/hooks.test.sh`
`git ls-files '*.sh' bin/* | xargs -n1 bash -n && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
- `raw-journal.sh`: `journal_prompt` counts `NOTICE_RE` matches with jq. The pattern is passed via `--arg`, because jq literals reject regex escapes. With 0 matches it takes the old path byte for byte. Otherwise it writes the human remainder, trimmed at the ends, as `## user` first, then one `## notice · <ts> · <kind>` per segment in prompt order. `append_block` takes an optional kind.
- `tests/hooks.test.sh`: 13 cases (notification-only, pasted between human parts, system-reminder / cross-session kinds, an unclosed tag, a no-tag prompt byte for byte). HEAD's hook fails 9 of them.

## Findings
