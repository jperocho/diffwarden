# Diffwarden

[![skills.sh](https://skills.sh/b/jperocho/diffwarden)](https://skills.sh/jperocho/diffwarden/diffwarden)

Independent PR guardian skill.

Diffwarden inspects pull-request diffs, checks, review comments, and risky code paths. It classifies findings, plans scoped fixes, verifies changes, and loops until the PR is merge-ready or blocked.

It is designed for any coding agent or automation system that can read a skill/playbook, run shell commands, inspect files, and make safe edits.

## Core loop

```text
preflight -> detect PR -> collect evidence -> classify -> plan fixes -> apply safe fixes -> verify -> optional push -> re-check -> report
```

## Safety stance

- No auto-merge.
- No force-push.
- No blind push.
- No resolving human review comments without explicit approval.
- No weakening CI, tests, lint, branch protection, auth, secrets, or infra config to pass checks.
- Stops on dirty unrelated worktree, ambiguous risk, external PR head change, or non-converging loops.

## Install

Install with skills.sh:

```bash
npx skills add https://github.com/jperocho/diffwarden --skill diffwarden
```

Use manually with any coding agent that supports markdown procedures or custom skill files:

```bash
mkdir -p ~/.config/agent-skills/diffwarden
cp skills/diffwarden/SKILL.md ~/.config/agent-skills/diffwarden/SKILL.md
```

If your agent has no native skill loader, paste `skills/diffwarden/SKILL.md` into the agent context before the PR task.

## Usage

```text
Use diffwarden on PR <number-or-url>
```

Useful modes:

- `--dry-run`: collect evidence and plan only.
- `--no-push`: local fixes only.
- `--security-focus`: prioritize security-sensitive review.
- `--post-review`: post findings to the PR as a GitHub `COMMENT` review (and optional inline comments). Off by default; requires explicit authorization. Never approves, requests changes, or merges.
- `--max-iterations N`: default 3; hard max 5 unless explicitly overridden.

## Requirements

- coding agent capable of reading markdown procedures / skills
- `git`
- GitHub CLI: `gh`
- authenticated GitHub session: `gh auth status`
- repository with an active GitHub pull request

## Files

- `skills/diffwarden/SKILL.md` — PR review skill/playbook.
- `CHANGELOG.md` — release notes.
- `CLAUDE.md` / `AGENTS.md` — agent guidance (`AGENTS.md` symlinks `CLAUDE.md`).
- `LICENSE` — MIT.
- `.gitignore` — local/editor/cache exclusions.

## Version

Current version: `v0.2.0`
