# CLAUDE.md

Guidance for AI coding agents working in this repo.
`AGENTS.md` is a symlink to this file — edit only this one.

## What this repo is

A single distributable **agent skill**, not an application. The product is one
markdown playbook: `skills/diffwarden/SKILL.md`. Everything else documents it.
No source code, build step, or test suite.

```
skills/diffwarden/SKILL.md     ← the product (PR-guardian playbook)
skills/diffwarden/commands/    ← optional Cursor slash files (user copies locally)
README.md                      ← user-facing description / install / usage
CHANGELOG.md                ← release notes (Keep a Changelog + SemVer)
LICENSE                     ← MIT
CLAUDE.md / AGENTS.md       ← agent guidance (AGENTS.md symlinks CLAUDE.md)
```

## Editing rules

- `SKILL.md` is the source of truth. When it changes, update README and
  CHANGELOG to match.
- Match the existing voice: terse, imperative, bullet- and code-block-driven.
  No marketing prose.
- Never soften the safety stance: no auto-merge, no force-push, no blind push,
  no weakening CI/tests/lint/auth/secrets, no resolving human comments without
  explicit approval. These are the skill's core promise.
- Keep `SKILL.md` frontmatter valid: `name`, `description`, `version`,
  `author`, `license`, `metadata.tags`, `metadata.related_skills`.

## Version bumps (do all together)

`version` is duplicated in four places — they must stay in sync:

1. `skills/diffwarden/SKILL.md` frontmatter `version:`
2. `README.md` — `Current version: vX.Y.Z`
3. `README.md` — version badge `version-X.Y.Z-blue.svg`
4. `CHANGELOG.md` — new `## [X.Y.Z] - YYYY-MM-DD` section

Use SemVer. Add a CHANGELOG entry for every user-visible change.

## Verification

No automated tests. To "verify" a change:

- Re-read `SKILL.md` end-to-end for internal consistency (loop steps, stop
  conditions, classification taxonomy must not contradict each other).
- Confirm version sync across the three files above.
- Confirm README install/usage commands still match the skill.

## Distribution

Installed via skills.sh: `npx skills add https://github.com/jperocho/diffwarden --skill diffwarden`.
Path layout `skills/<name>/SKILL.md` is required by the loader — do not move it.
