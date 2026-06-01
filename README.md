# Diffwarden

[![skills.sh](https://skills.sh/b/jperocho/diffwarden)](https://skills.sh/jperocho/diffwarden/diffwarden)
[![version](https://img.shields.io/badge/version-0.6.0-blue.svg)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Independent PR guardian skill. You tell your coding agent "use diffwarden on this PR" and it reviews the pull request like a careful senior engineer: reads the diff, CI checks, and review comments; finds bugs and risks; fixes safe ones; verifies; and stops before doing anything dangerous.

It never auto-merges, never force-pushes, and never weakens your tests or CI to make a check go green.

## Contents

- [What it actually does](#what-it-actually-does)
- [Is this for me?](#is-this-for-me)
- [Prerequisites (do this first)](#prerequisites-do-this-first)
- [Install](#install)
- [Slash commands](#slash-commands)
- [Your first run (step by step)](#your-first-run-step-by-step)
- [Modes / flags](#modes--flags)
- [Common recipes](#common-recipes)
- [What it will and won't do](#what-it-will-and-wont-do)
- [Core loop](#core-loop)
- [Troubleshooting / FAQ](#troubleshooting--faq)
- [Files](#files)
- [Version](#version)

## What it actually does

This repo is **not an app**. It is one markdown playbook (`skills/diffwarden/SKILL.md`) that teaches an AI coding agent (Claude Code, Copilot CLI, Cursor, etc.) a safe, repeatable way to babysit a pull request.

Given a PR, the agent:

1. Checks your environment is safe to work in (git repo, logged into GitHub, right branch).
2. Reads everything: the diff, CI status, inline review comments, bot comments.
3. Sorts findings into: must-fix now, FYI, already fixed, or "ask the human".
4. Ranks by severity (P0 security/data-loss down to P3 polish).
5. Writes a small fix plan, applies safe fixes, and runs your tests/linters to prove they work.
6. Optionally posts the review on GitHub or commits fixes — only if you allow it.
7. Loops until the PR is merge-ready, blocked, or it needs your decision.

## Is this for me?

Use it if you want to:

- check a PR before merging it
- get failing CI checks fixed safely
- review a teammate's PR and leave comments on GitHub
- do a focused security pass on changed code

Don't use it for: deploying to production, auto-merging, rewriting git history, or large refactors unrelated to the PR.

## Prerequisites (do this first)

You need four things. Check each before installing.

**1. A coding agent that can read skills and run shell commands.** Examples: Claude Code, GitHub Copilot CLI, Cursor, OpenCode. (See the full compatibility list on the [skills.sh page](https://skills.sh/jperocho/diffwarden/diffwarden).)

**2. `git`.**

```bash
git --version   # any recent version is fine
```

**3. GitHub CLI (`gh`).**

```bash
gh --version    # if "command not found", install it:

# macOS
brew install gh
# Debian / Ubuntu
sudo apt install gh
# Windows
winget install --id GitHub.cli
```

**4. A logged-in GitHub session.**

```bash
gh auth status        # should say "Logged in to github.com"
gh auth login         # run this if it doesn't
```

You also need to be inside a git repository that has an open GitHub pull request.

## Install

**Option A — skills.sh (recommended).** Run this in your project folder:

```bash
npx skills add https://github.com/jperocho/diffwarden --skill diffwarden
```

This drops the skill where your agent can find it automatically.

**Option B — manual copy.** For agents with a custom skill folder:

```bash
mkdir -p ~/.config/agent-skills/diffwarden
cp skills/diffwarden/SKILL.md ~/.config/agent-skills/diffwarden/SKILL.md
```

**Option C — no skill loader.** Paste the contents of `skills/diffwarden/SKILL.md` into your agent's context before you give it the PR task.

## Slash commands

Use `/diffwarden` or the alias `/dw`. PR can be `#123`, `123`, `current`, a full GitHub PR URL, or omitted (current branch PR).

| Command | What it does |
|---------|--------------|
| `review [<pr>]` | Read-only review and fix plan. **No edits, commits, or push.** Default: no PR comments. |
| `review [<pr>] --comment` | Same as `review`, but posts a `COMMENT`-only GitHub review (needs your OK each run). |
| `fix [<pr>]` | Fix safe issues locally and verify. **No push.** |
| `fix [<pr>] --push` | Fix locally, then commit and push when verified. |
| `prepare [<pr>]` | Full PR prep: fix, verify, commit, and push. |
| `prepare [<pr>] --comment` | Full prep plus post a `COMMENT`-only review. |
| `security [<pr>]` | Read-only security-focused pass. |
| `security [<pr>] --comment` | Security pass plus post findings on the PR. |
| `status [<pr>]` | Quick merge-readiness snapshot (checks, score, blockers). |
| `help` | List commands. Bare `/diffwarden` shows help. |

**Flags** (combine on any applicable command):

| Flag | Effect |
|------|--------|
| `--comment` | Post findings as a GitHub `COMMENT` review (never approve or request changes). |
| `--security` | Prioritize auth, injection, SSRF, secrets, path traversal, crypto, data loss. |
| `--max N` | Loop iterations (default `3`, max `5`). |
| `--dry-run` | On `fix` only: plan without editing (same as `review`). |

**Examples:**

```text
/diffwarden review #123
/diffwarden review #123 --comment
/diffwarden fix
/diffwarden fix #123 --security
/diffwarden prepare #123 --comment
/dw status
/dw help
```

Equivalent natural-language prompts still work:

```text
Use diffwarden on the current PR --dry-run
Use diffwarden on PR https://github.com/owner/repo/pull/123 --no-push
```

## Your first run (step by step)

1. `cd` into your repo and switch to the PR's branch.
2. Confirm you're set up:

   ```bash
   gh auth status
   gh pr view            # should show the current PR
   ```

3. In your agent, type:

   ```text
   /diffwarden review
   ```

   Or the long form:

   ```text
   Use diffwarden on the current PR --dry-run
   ```

   Both mean **review and plan only — change nothing.** Best way to start: zero risk.

4. Read the report. It lists findings, severity, and a fix plan.
5. When ready to let it act, drop `--dry-run`:

   ```text
   /diffwarden fix
   ```

   Or:

   ```text
   Use diffwarden on PR https://github.com/owner/repo/pull/123
   ```

If you omit the PR number/URL, it detects the PR from your current branch.

## Modes / flags

Add these after the command. Combine freely.

| Flag | What it does |
|------|--------------|
| `--dry-run` | Review and plan only. No edits, commits, pushes, or comments. **Start here.** |
| `--no-push` | Apply fixes locally but never push them. |
| `--security-focus` | Prioritize security: auth, injection, SSRF, secrets, path traversal, crypto, data loss. |
| `--post-review` | Post findings to the PR as a GitHub `COMMENT` review (plus optional inline comments). Off by default; needs your explicit OK each run. Never approves, requests changes, or merges. |
| `--max-iterations N` | How many review→fix→verify rounds. Default `3`; hard max `5` unless you say otherwise. |

## Common recipes

**Review your own PR before merge (safe, read-only):**

```text
/diffwarden review
```

**Review a teammate's PR and post comments on GitHub:**

```text
/diffwarden review #123 --comment
```

Posts a `COMMENT`-type review with inline notes. It will **not** approve or request changes — that decision stays yours.

**Security-focused pass:**

```text
/diffwarden security #123
```

**Let it fix safe issues locally, but don't push:**

```text
/diffwarden fix
```

## What it will and won't do

**Will:**

- Read diffs, checks, and comments.
- Fix safe, in-scope issues and run tests to verify.
- Post comment-only reviews (with `--post-review` + your OK).
- Commit/push **only** if you ask for full PR preparation.

**Won't (the safety promise):**

- No auto-merge.
- No force-push, no `git reset --hard`, no history rewrite.
- No blind push — it checks the PR head didn't change first.
- No approving or requesting changes on a PR.
- No resolving human review comments without your explicit approval.
- No weakening CI, tests, lint, branch protection, auth, secrets, or infra config to make checks pass.

**Stops and asks** on: dirty unrelated files, ambiguous risk, the PR head changing mid-run, protected branches, or a loop that isn't converging.

## Core loop

```text
preflight -> detect PR -> collect evidence -> classify -> plan fixes -> apply safe fixes -> verify -> optional post/push -> re-check -> report
```

## Troubleshooting / FAQ

**"It says I'm not authenticated."** Run `gh auth login`, then `gh auth status` to confirm.

**"It can't find a PR."** Make sure you're on the PR's branch, or pass the number/URL explicitly: `... on PR 123`.

**"It refuses to run on `main`/`master`."** By design. Switch to the PR's feature branch first.

**"It won't fix my failing CI by editing the workflow."** Also by design — it never weakens CI/tests to go green. Fix the real cause.

**"Will it merge my PR?"** No. Never. You merge.

**"Can it review a PR from a fork?"** It can review and (with `--post-review`) comment. It usually can't push fixes to a fork branch, so use `--no-push` / treat fixes as suggestions.

**"It stopped early."** It hit a safety stop (dirty worktree, ambiguous risk, head changed, max iterations). Read the report — it says why and what to do next.

## Files

- `skills/diffwarden/SKILL.md` — the skill/playbook (the actual product).
- `README.md` — this guide.
- `CHANGELOG.md` — release notes.
- `CLAUDE.md` / `AGENTS.md` — agent guidance (`AGENTS.md` symlinks `CLAUDE.md`).
- `LICENSE` — MIT.
- `.gitignore` — local/editor/cache exclusions.

## Version

Current version: `v0.6.0`
