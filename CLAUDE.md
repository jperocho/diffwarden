# CLAUDE.md

Guidance for AI coding agents working in this repo.
`AGENTS.md` is a symlink to this file — edit only this one.

## What this repo is

A single distributable **agent skill**, not an application. The product is one
markdown playbook: `skills/diffwarden/SKILL.md`. Everything else documents it.
No source code, build step, or test suite.

```
skills/diffwarden/SKILL.md     ← the product (PR-guardian playbook)
skills/diffwarden/commands/    ← optional slash files (/dw, /diffwarden)
skills/diffwarden/prompts/     ← Pi-only prompt templates ($ARGUMENTS); not for Codex
extensions/diffwarden/         ← optional Pi extension package wrapper (/dw commands)
docs/orchestration.md          ← optional orchestration guide (human docs)
install.sh                     ← installer (Claude/Cursor/Codex/Pi; copies skill + commands/prompts)
package.json                   ← Pi/npm package manifest (pi-diffwarden)
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

`version` is duplicated in eight places — they must stay in sync:

1. `skills/diffwarden/SKILL.md` frontmatter `version:`
2. `README.md` — `Current version: vX.Y.Z`
3. `README.md` — version badge `version-X.Y.Z-blue.svg`
4. `README.md` — installer curl URL `.../diffwarden/vX.Y.Z/install.sh`
5. `README.md` — Pi npm install URL `npm:pi-diffwarden@X.Y.Z`
6. `install.sh` — `DEFAULT_REF="vX.Y.Z"`
7. `package.json` — `"version": "X.Y.Z"`
8. `CHANGELOG.md` — new `## [X.Y.Z] - YYYY-MM-DD` section

Use SemVer. Add a CHANGELOG entry for every user-visible change.

## Verification

CI (`.github/workflows/ci.yml`) runs on every PR and push to main: it
shellchecks `install.sh` (`bash -n` + `shellcheck`), dry-runs Pi install,
checks the Pi/npm package, runs `npm pack --dry-run`, and enforces version sync
across all the files listed above. It is a required status check on `main`.
Beyond CI, to "verify" a change:

- Re-read `SKILL.md` end-to-end for internal consistency (loop steps, stop
  conditions, classification taxonomy must not contradict each other).
- Confirm version sync across the files above (CI also checks this).
- Confirm README install/usage commands still match the skill.

## Distribution

Installed via `install.sh` (detects Claude Code, Cursor, Codex, and Pi; copies
the skill and Claude/Cursor command files; Codex gets the skill only under
`.agents/skills/`; Pi gets skill + prompt templates under `.pi/` or
`~/.pi/agent/`), via Pi package (`pi install npm:pi-diffwarden@X.Y.Z` or git),
or by manual copy — there is **no** `npx`/skills.sh path (it was flaky and has
been removed). Do not re-add it without good reason.

The installer pins to a release tag (`DEFAULT_REF` in `install.sh`) and fetches
from `raw.githubusercontent.com/...` when run outside a clone — **bump
`DEFAULT_REF` and the README curl URL on every release** so a fresh download
installs the matching version. The source path `skills/diffwarden/SKILL.md` and
`skills/diffwarden/commands/` and `skills/diffwarden/prompts/` are hard-coded in
the installer — don't move them.

Security stance for `install.sh`: keep `set -euo pipefail`, HTTPS-only fetch, no
`sudo`, and the guard that refuses writes outside `.claude/`, `.cursor/`,
`.agents/`, Pi roots (`skills/` + `prompts/` only), and optional
`~/.config/diffwarden/` (orchestration defaults only, after user confirmation).
