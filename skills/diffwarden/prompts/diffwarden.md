# /diffwarden

Read and follow the diffwarden skill (`SKILL.md`). Invoke with: $ARGUMENTS

Every final review/loop/status/comment must end with exactly two lines: `Status: ready | not-ready | blocked | user decision needed` then `Level: N/5`. This contract is mandatory even when invoked through Pi, master, or orchestration wrappers — those wrappers do not replace these final lines.
