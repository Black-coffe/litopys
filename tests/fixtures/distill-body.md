# Resume and compaction survive one journal

## Decisions
- One journal file is one session record, whatever the markers inside it.
- `ended` is the last `## closed` only when nothing follows it.

## Corrections
- (none)

## Problems
- A token was pasted into the session: ghp_abcdefghijklmnopqrstuvwxyz0123456789
- The journal keeps it; the record must not.

## Brainstorm
- (none)

## Links
- docs/wiki/chronicle-format.md - C8 blocks this parser reads
