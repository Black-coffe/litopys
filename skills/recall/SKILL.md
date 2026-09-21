---
name: recall
description: Answers a question about this project's history from git and docs, returning an answer with refs only. Trigger with /litopys:recall <question> to search project history and answer with refs.
context: fork
agent: recall
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git tag:*), Bash(git show:*)
---

# `/litopys:recall`

Question: `$ARGUMENTS`

Answer this question about the project's history. You run in a forked context: only your
final answer reaches the caller, never your search process.

## Search order

Search in this fixed order, stopping once you can answer confidently:
1. `docs/chronicle/sessions/` - distilled session records (grep the frontmatter `topics:` and
   `links:` lines first, then the bodies); cite the record path in `**Refs:**`
2. `docs/chronicle/` - dated project journal
3. `docs/specs/*/brief.md` - what was asked and why, per spec
4. `docs/adr/` - decisions and their rationale
5. `docs/grill/` - raw discovery/synthesis documents
6. `CHANGELOG*` - shipped changes, versions
7. `git tag` - version/release markers
8. `git log --oneline` - commit history, drilling down with `git show <sha>` or
   `git log -S"<term>"` when a candidate commit needs confirming

## Return

Return only:
```
**Answer:** <at most 10 lines>
**Refs:**
- <repo-relative path or 7-char sha> - <why>
**Confidence:** high | medium | low
```

If nothing in the search order answers the question, do not guess. Say
"Not found in project history" and list the paths/stages you searched, instead of inferring
an answer from adjacent context.
