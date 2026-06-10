# Diffwarden

[![version](https://img.shields.io/badge/version-0.23.2-blue.svg)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Independent PR guardian skill. You tell your coding agent "use diffwarden on this PR" and it reviews the pull request like a careful senior engineer: reads the diff, CI checks, and review comments; finds bugs and risks; fixes safe ones; verifies; and stops before doing anything dangerous.

It never auto-merges, never force-pushes, and never weakens your tests or CI to make a check go green.

## Contents

- [Command reference](#command-reference)
- [Review uncommitted changes (no PR)](#review-uncommitted-changes-no-pr)
- [Auto-detected mode (code vs plan)](#auto-detected-mode-code-vs-plan)
- [Web-augmented review (opt-in)](#web-augmented-review-opt-in)
- [Loop until merge-ready (5/5)](#loop-until-merge-ready-55)
- [What it actually does](#what-it-actually-does)
- [Is this for me?](#is-this-for-me)
- [Prerequisites (do this first)](#prerequisites-do-this-first)
- [Install](#install)
- [Slash commands](#slash-commands)
- [Codex CLI](#codex-cli)
- [Your first run (step by step)](#your-first-run-step-by-step)
- [Modes / flags](#modes--flags)
- [Common recipes](#common-recipes)
- [What it will and won't do](#what-it-will-and-wont-do)
- [Core loop](#core-loop)
- [Troubleshooting / FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
- [Files](#files)
- [Version](#version)

## Command reference

Invoke with `/diffwarden` (or the optional `/dw` alias). There is **one** `review` and **one** `fix`; both auto-detect the target. Target arg: a PR (`#123`, `123`, full URL, `current`, or omit for the current branch PR), a local target — `local`, `staged`, or `worktree` — to review **uncommitted changes with no PR** (see [Review uncommitted changes](#review-uncommitted-changes-no-pr)), or a single prose `.md` plan file to **critique/revise a plan before coding** (see [Auto-detected mode](#auto-detected-mode-code-vs-plan)). Natural-language prompts still work — see [Slash commands](#slash-commands).

**What works out of the box:** once the skill is installed (see [Install](#install)), `/diffwarden` registers in **Claude Code** automatically (it matches the skill name). The shorthand `/dw` needs command files in Claude Code/Cursor. **Codex CLI is different** — see [Codex CLI](#codex-cli): use `$diffwarden` or `/skills`, not `/dw` or `/diffwarden`.

| Command | What it does |
|---------|--------------|
| `/diffwarden review [<target>]` | Read-only review + fix plan. No edits, commits, or push. Auto-detects code vs plan target; prints `detected: code review` / `detected: plan review`. |
| `/diffwarden review [<pr>] --comment` | Same, plus post `COMMENT`-only GitHub review (your OK each run). |
| `/diffwarden fix [<target>]` | Fix safe issues locally + verify. No push. Auto-detects code vs plan target; prints `detected: code fix` / `detected: plan fix`. |
| `/diffwarden fix [<pr>] --push` | Fix locally, commit + push when verified. |
| `/diffwarden fix [<pr>] --reply` | Fix locally + reply on reviewer threads (your OK). |
| `/diffwarden fix [<pr>] --reply --resolve` | Fix + thread replies + resolve fixed threads (your OK). |
| `/diffwarden prepare [<pr>]` | Full prep: fix, verify, commit, push. |
| `/diffwarden prepare [<pr>] --reply --resolve` | Full prep + replies + resolve fixed threads. |
| `/diffwarden prepare [<pr>] --comment` | Full prep + post `COMMENT`-only review. |
| `/diffwarden security [<pr>]` | Read-only security-focused pass. |
| `/diffwarden security [<pr>] --comment` | Security pass + post findings on PR. |
| `/diffwarden status [<pr>]` | Quick merge-readiness snapshot (checks, score, blockers). |
| `/diffwarden review <plan.md>` | Critique a plan/design file before coding (read-only, no PR). Plan mode auto-detected from the `.md` target. |
| `/diffwarden fix <plan.md>` | Revise a plan file in place to address findings (loops to 5/5; backs up to `<plan>.orig`). Plan mode auto-detected. |
| `/diffwarden review <plan.md> --as-code` | Force code (diff) review of a `.md` file instead of plan critique. |
| `/diffwarden review local` | Review uncommitted changes (vs `HEAD` + untracked), no PR. |
| `/diffwarden review staged` | Review staged changes only, no PR. |
| `/diffwarden fix local` | Fix safe issues in the working tree (no commit, no push). |
| `/diffwarden security local` | Security-focused pass on uncommitted changes. |
| `/diffwarden help` | List commands. Bare `/diffwarden` = help. |

| Flag | Effect |
|------|--------|
| `--as-code` | On `review`/`fix`: force code mode (override the target detector). |
| `--as-plan` | On `review`/`fix`: force plan mode. Invalid on a PR / `local` / `staged` / `worktree` target. |
| `--comment` | Post new `COMMENT` review (never approve or request changes). |
| `--reply` | Reply on existing reviewer threads (`fixed`, `defer`, `wontfix`, …). |
| `--resolve` | Resolve threads after `fixed` / `already-addressed` replies (needs `--reply` + OK). |
| `--security` | Prioritize auth, injection, SSRF, secrets, path traversal, crypto, data loss. |
| `--web` | Opt into [web-augmented review](#web-augmented-review-opt-in) (alias `--research`). Off by default; asks `[y/N]` before each web search and only sends a redacted finding descriptor. |
| `--push` | On `fix` only: allow commit + push after verify. |
| `--max N` | Loop iterations (default `3`, max `5`). |
| `--dry-run` | On `fix` only: plan without editing (= `review`). |

## Review uncommitted changes (no PR)

Pass a local target instead of a PR to review your working tree before you
commit or open a PR. No GitHub access, no CI, no review threads — just the diff,
your project context, and the same review pipeline.

| Target | Diff scope |
|--------|------------|
| `local` / `worktree` | All changes vs `HEAD` **plus** untracked files (gitignored excluded). |
| `staged` | Staged changes only (`git diff --cached`). |

```text
/dw review local          # read-only review of everything uncommitted
/dw review staged         # review only what you've git add-ed
/dw fix local             # review + apply safe fixes to the working tree (no commit/push)
/dw security local        # security-focused pass on uncommitted changes
```

Valid with `review`, `fix`, `prepare`, and `security`. Everything that defines a
review still runs — classification, severity, confidence score, fix loop,
verification, security checklist. What's skipped (no PR exists): PR detection,
CI, review/issue comments, posting (`--comment`/`--reply`/`--resolve`), and any
commit or push (`fix local` and `prepare local` edit the working tree only). The
confidence score reports `checks: n/a (local)` and reflects readiness-to-commit.
`status` and posting/push flags are rejected with a local target.

## Auto-detected mode (code vs plan)

`review` and `fix` are single commands that work on **either** code or a plan
document. Diffwarden classifies the *target* and runs the matching mode — you do
not pick a separate subcommand. Every run prints the mode it chose:
`detected: code review | plan review | code fix | plan fix`.

| Target | Detected mode |
|--------|---------------|
| `#123`, `123`, full PR URL, `current`, or omitted | code |
| `local`, `staged`, `worktree` | code |
| a single prose `.md` plan file (headings/sections, no diff) | plan |
| `--as-code` flag | code (forced) |
| `--as-plan` flag | plan (forced) |
| **mixed** signals (e.g. a PR *and* a `.md` plan) | **asks you; default code** |

```text
/dw review #123            # detected: code review
/dw review                 # detected: code review (current branch / worktree)
/dw review docs/plan.md    # detected: plan review (critique a plan, no PR)
/dw review docs/plan.md --as-code   # detected: code review (review the file as a diff)
/dw fix #123               # detected: code fix
/dw fix docs/plan.md       # detected: plan fix (revise the plan in place, no PR)
/dw fix docs/plan.md --as-plan      # detected: plan fix (explicit)
```

`--as-code` / `--as-plan` override the detector; on a mix of signals Diffwarden
**asks first** (defaulting to code only if you don't choose) — it never silently
guesses. Plan mode never touches a PR, git, or code: plan `review` is a read-only
critique; plan `fix` revises only the plan file (backing up to `<plan>.orig`) and
never commits or pushes. `prepare`, `security`, and `status` are code-only.

> The older `review-plan` / `fix-plan` names still work as **hidden back-compat
> aliases** (equivalent to `review` / `fix <file> --as-plan`), but `review` /
> `fix` on a `.md` file is the way to invoke plan mode now.

## Web-augmented review (opt-in)

Off by default. Diffwarden grounds its findings against your repo and the diff —
**never the internet** — unless you turn this on with `--web` (alias
`--research`). Even then it never searches silently: on an **uncertain** finding
it asks first and waits for your `y`.

Two gates, both required:

1. **You pass `--web`.** Without it, Diffwarden never touches the network for a
   review. (The only other network call is the help-path version check.)
2. **Per finding, it asks and waits:**

   ```text
   I am unsure about <finding>. Search the web to verify? [y/N]
   Query (redacted): "<minimal finding descriptor>"
   ```

   Default is **No**. Anything but `y` skips the search and keeps the finding
   `local-only`. No batch-approve, no assuming consent from the flag.

**When it offers a search:** only on genuine uncertainty — a low-confidence
finding, something time-sensitive (a CVE, a security advisory, a deprecation, a
current best practice or idiomatic pattern), or when you asked for a
deep/verbose review. High-confidence, locally-provable findings are never sent
out.

**What leaves your machine:** the **minimal finding descriptor only** — the
abstract shape of the issue (e.g. "Express open-redirect via unvalidated user
input"). Never your code, diff, secrets, tokens, file paths, or internal names.
The exact redacted query is shown in the prompt — what you approve is what's
sent. A web search is egress to a third party that may be logged or indexed;
that's why it's gated, redacted, and minimized.

**Output:** every finding is marked `web-verified` (a consented search grounded
it; URL cited) or `local-only` (the default). Web grounding **never** raises
severity on its own and never bypasses a safety cap — severity and the
confidence score stay Diffwarden's own judgment.

Valid on `review`, `fix`, `prepare`, and `security` (code targets, including
`local` / `staged` / `worktree`), and compatible with `--dry-run` and
`--security`. Rejected on `status` (snapshot only) and on plan mode (`--as-plan`
or a `.md` plan target) — plan critique grounds against your repo, not the web.

```text
/dw review #123 --web      # asks [y/N] before grounding any uncertain finding
/dw fix --web --security   # security run reads raw; web grounding still per-finding gated
```

## Loop until merge-ready (5/5)

Diffwarden loops automatically inside `fix` and `prepare` — no separate loop command.
Each round: preflight → collect evidence → score confidence → fix safe issues →
verify → optional commit/push → re-check. Stops at **5/5** or a safety stop.

### Commands

| Goal | Command |
|------|---------|
| Loop locally (no push) | `/dw fix --max 5` |
| Loop + commit + push | `/dw prepare --max 5` |
| Check score only | `/dw status` |
| Loop + reply on review threads | `/dw prepare --max 5 --reply --resolve` |

Natural language: `Use diffwarden on the current PR --max-iterations 5`

Default **3** iterations; hard max **5** unless you explicitly ask for more in chat.

### What 5/5 means

All must be true:

- Required CI checks pass
- No actionable findings remain
- No open P0/P1/security issue
- PR description has adequate summary, testing, and risk notes
- Review comments addressed or classified already-addressed with evidence

Score is recomputed from evidence every iteration. **5/5 does not auto-merge** — you merge.

### Confidence scale (short)

| Score | Meaning |
|-------|---------|
| `5/5` | Merge-ready (loop stops) |
| `4/5` | Only P3 / informational items left |
| `3/5` | P2 issues or missing targeted test |
| `2/5` | P1 issue or failing required check |
| `0-1/5` | P0, security, or hard build failure |

Safety caps: unresolved P0/security → max `1/5`; failing required check → max `2/5`;
needs-user-decision → max `3/5` until you decide.

### When it stops before 5/5

| Reason | What to do |
|--------|------------|
| Hit `--max 5` | Run again: `/dw prepare --max 5` |
| Needs user decision (API, product, migration…) | Answer in chat, re-run |
| Same finding repeats | Agent stops — fix root cause manually |
| CI still pending | Wait for green, then `/dw status` |
| Dirty unrelated files | Clean worktree or stash first |

### Example workflow

```text
/dw status
/dw prepare --max 5
/dw prepare --max 5 --reply --resolve
```

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

**1. A coding agent that can read skills and run shell commands.** Examples: Claude Code, Codex, GitHub Copilot CLI, Cursor, OpenCode. The installer targets Claude Code, Codex, and Cursor directly; any other skill-loading agent works via manual copy ([Install](#install) Option C/D).

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

Optional: export `GH_TOKEN` (or `GITHUB_TOKEN`) for CI/automation when `gh auth
login` is not available. Diffwarden tries `gh auth status` first; if you are
logged in, it ignores env tokens for that session so `gh` uses your user. With
no active user, it validates env tokens with `gh api user`. It never searches
files or config for tokens.

You also need to be inside a git repository that has an open GitHub pull request.

## Install

There is **no `npx`/skills.sh step** — that loader proved flaky, so Diffwarden
installs with its own script or a plain copy. Both place the same files:

- the skill itself → `<root>/.claude/skills/diffwarden/SKILL.md` (Claude Code),
  `<root>/.agents/skills/diffwarden/SKILL.md` (Codex), and/or
  `<root>/.cursor/skills/diffwarden/SKILL.md` (Cursor),
- the optional `/dw` and `/diffwarden` slash-command files → `<root>/.claude/commands/`
  and/or `<root>/.cursor/commands/` (Claude Code and Cursor only — Codex does not
  use command files; see [Codex CLI](#codex-cli)),

where `<root>` is your project folder (project scope) or `$HOME` (global scope).

**Option A — installer (recommended).** It detects which agents you have, asks
where to install, copies the skill + command files into the right places,
skips files already up to date, and never overwrites a changed file without
asking.

> **Security — inspect before you run.** Diffwarden is a safety tool; don't
> pipe a script straight into a shell on its word. Download it, read it, then
> run it. The installer pins to a release tag, uses HTTPS only, never uses
> `sudo`, and only writes under `.claude/`, `.cursor/`, and `.agents/`.

```bash
# Recommended: download → read → run
curl -fsSLO https://raw.githubusercontent.com/jperocho/diffwarden/v0.23.2/install.sh
less install.sh        # read it first
bash install.sh        # interactive: detects agents, asks scope, confirms

# Or run it straight from a clone (no network):
git clone https://github.com/jperocho/diffwarden
cd diffwarden && ./install.sh
```

Useful flags (see `./install.sh --help`):

```bash
./install.sh --dry-run            # show the plan, write nothing
./install.sh --claude --project   # Claude Code, current repo only
./install.sh --codex --global     # Codex, all projects on this machine
./install.sh --cursor --global    # Cursor, all projects on this machine
./install.sh --yes                # non-interactive (accept detected defaults)
./install.sh --force              # overwrite differing files without prompting
```

**Option B — manual copy.** Do exactly what the installer does, by hand. Pick a
`<root>` (`.` for this project, `~` for global) and the matching agent location:

```bash
# Claude Code, project scope
mkdir -p .claude/skills/diffwarden .claude/commands
cp skills/diffwarden/SKILL.md          .claude/skills/diffwarden/SKILL.md
cp skills/diffwarden/commands/dw.md    .claude/commands/
cp skills/diffwarden/commands/diffwarden.md .claude/commands/

# Codex, project or global scope (same skill path; invoke with $diffwarden)
mkdir -p .agents/skills/diffwarden
cp skills/diffwarden/SKILL.md          .agents/skills/diffwarden/SKILL.md
# global: mkdir -p ~/.agents/skills/diffwarden && cp ... ~/.agents/skills/diffwarden/

# Cursor, project scope — same files under .cursor/
mkdir -p .cursor/skills/diffwarden .cursor/commands
cp skills/diffwarden/SKILL.md          .cursor/skills/diffwarden/SKILL.md
cp skills/diffwarden/commands/dw.md    .cursor/commands/
cp skills/diffwarden/commands/diffwarden.md .cursor/commands/
```

For global Claude Code/Cursor scope, swap the leading `.` for `~`. For global
Codex skills, use `~/.agents/skills/diffwarden/SKILL.md`.

Claude Code and Codex load skills at session start — restart (or `/clear` in
Codex) after installing. Codex invocation details: [Codex CLI](#codex-cli).

**Optional — caveman mode for token savings.** Diffwarden runs long review loops
(diffs, CI logs, threads), so it pairs well with the [`caveman`](https://github.com/JuliusBrussee/caveman)
skill, which compresses agent output ~75% with no loss of technical substance. If
`caveman` is loaded, Diffwarden runs in caveman mode automatically; if not, it prints
a one-time install tip and continues normally.

Caveman activation differs by agent:

- **Claude Code / Codex / Gemini** — hook-driven, auto-activates per session once installed.
- **Cursor / Windsurf / Cline / Copilot** — no hook system; activation is a static
  rule file. For Cursor, install the rule into `.cursor/rules/`:

  ```bash
  npx skills add JuliusBrussee/caveman -a cursor --with-init
  ```

  > **Caution for this repo only:** `--with-init` also writes repo-root `AGENTS.md`,
  > which in this project is a symlink to `CLAUDE.md`. Running it here would modify
  > project instructions. Instead, copy just the Cursor rule by hand:
  >
  > ```bash
  > mkdir -p .cursor/rules
  > cp ~/.claude/plugins/marketplaces/caveman/src/rules/caveman-activate.md \
  >    .cursor/rules/caveman.mdc
  > echo ".cursor/rules/caveman.mdc" >> .gitignore   # keep out of the distributable
  > ```

Cursor reads only `.cursor/` and repo-root `AGENTS.md`; it never reads Claude's
`~/.claude` install, so the two stay isolated.

**Option C — other agents / custom skill folder.** Copy the skill wherever your
agent loads skills from:

```bash
mkdir -p ~/.config/agent-skills/diffwarden
cp skills/diffwarden/SKILL.md ~/.config/agent-skills/diffwarden/SKILL.md
```

**Option D — no skill loader.** Paste the contents of `skills/diffwarden/SKILL.md` into your agent's context before you give it the PR task.

## Slash commands

Examples and natural-language form. Full command table: [Command reference](#command-reference).

```text
/diffwarden review #123
/diffwarden review #123 --comment
/diffwarden fix
/diffwarden fix #123 --security
/diffwarden fix #123 --reply --resolve
/diffwarden prepare #123 --comment
/dw status
/dw help
```

Natural-language equivalents:

```text
Use diffwarden on the current PR --dry-run
Use diffwarden on PR https://github.com/owner/repo/pull/123 --no-push
```

## Codex CLI

Codex installs and runs Diffwarden as a **skill**, not as custom slash commands.
The grammar is the same; only the prefix changes.

### Supported

| How | Example |
| --- | --- |
| Skill install path | `.agents/skills/diffwarden/SKILL.md` or `~/.agents/skills/diffwarden/SKILL.md` |
| Explicit invocation | `$diffwarden review`, `$diffwarden fix local` (`status` needs an open PR) |
| Skill picker | `/skills` → choose **diffwarden** |
| Plain chat | Works when the task matches the skill description (implicit load) |

After install, restart Codex or run `/clear` so it rescans skills.

### Not supported (and why)

| What you might expect | Why it does not work |
| --- | --- |
| `/diffwarden`, `/dw` in the `/` menu | Codex `/` commands are **built-in only** (`/skills`, `/review`, `/model`, …). Custom slash commands from skill or command files are not loaded. OpenAI directs skill use through `$skill-name` instead ([codex#11817](https://github.com/openai/codex/issues/11817)). |
| `/prompts:diffwarden`, `/prompts:dw` | **Custom prompts** in `~/.codex/prompts/` were [deprecated](https://developers.openai.com/codex/custom-prompts) and **removed in the March 2026 Codex release** (0.117 series). OpenAI consolidated on Agent Skills as the standard; overlapping prompt-slash machinery was dropped ([codex#15941](https://github.com/openai/codex/issues/15941)). |
| `.codex/commands/` or `.codex/skills/` | Legacy paths. Current Codex reads skills from `.agents/skills` / `~/.agents/skills` per [customization docs](https://developers.openai.com/codex/concepts/customization). |

There is no `/dw` shorthand on Codex unless you add a separate skill named `dw`.
Use `$diffwarden` — same subcommands and flags as the [command reference](#command-reference).

```text
$diffwarden review
$diffwarden review #123 --comment
$diffwarden fix local
$diffwarden status         # PR only — needs gh + an open pull request
/skills                    # pick diffwarden from the menu
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
| `--as-code` / `--as-plan` | Force `review`/`fix` into code or plan mode, overriding the [target detector](#auto-detected-mode-code-vs-plan). |
| `--dry-run` | Review and plan only. No edits, commits, pushes, or comments. **Start here.** |
| `--no-push` | Apply fixes locally but never push them. |
| `--security-focus` | Prioritize security: auth, injection, SSRF, secrets, path traversal, crypto, data loss. |
| `--post-review` | Post findings to the PR as a GitHub `COMMENT` review (plus optional inline comments). Off by default; needs your explicit OK each run. Never approves, requests changes, or merges. |
| `--reply-comments` | Reply on existing inline review threads after fixes. Types: `fixed`, `already-addressed`, `defer`, `wontfix`, `needs-user`. Off by default; needs your OK each run. |
| `--resolve-replied` | Resolve threads after `fixed` / `already-addressed` replies. Requires `--reply-comments` and explicit OK. |
| `--web` / `--research` | Opt into [web-augmented review](#web-augmented-review-opt-in). Off by default; even when set, Diffwarden asks `[y/N]` and waits before each web search and only sends a redacted finding descriptor. Code targets only; rejected on `status` and plan mode. |
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

**Address review feedback and reply on threads:**

```text
/diffwarden fix #123 --reply --resolve
```

Replies on each addressed inline comment (`fixed in abc123…`). Resolves threads only when type is `fixed` or `already-addressed` and you authorized `--resolve`.

**Let it fix safe issues locally, but don't push:**

```text
/diffwarden fix
```

## What it will and won't do

**Will:**

- Read diffs, checks, and comments.
- Fix safe, in-scope issues and run tests to verify.
- Reply on reviewer comment threads (with `--reply-comments` + your OK).
- Resolve fixed threads (with `--resolve-replied` + your OK).
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
preflight -> detect PR -> collect evidence -> classify -> plan fixes -> apply safe fixes -> verify -> optional commit/push -> optional thread replies/resolve -> optional post-review -> re-check -> report
```

## Troubleshooting / FAQ

**" `/dw` doesn't show in the `/` menu."** For Claude Code/Cursor, the command files weren't installed; copy `dw.md` / `diffwarden.md` into `.claude/commands/`, `~/.claude/commands/`, `.cursor/commands/`, or `~/.cursor/commands/`, then restart. For **Codex CLI**, `/dw` and `/diffwarden` are **not supported** — the `/` menu is built-in commands only. Install the skill to `.agents/skills/diffwarden/` (or `~/.agents/skills/diffwarden/`), restart or `/clear`, then use `$diffwarden review ...` or `/skills`. See [Codex CLI](#codex-cli) for why `/prompts:dw` also no longer works on Codex ≥ 0.117.

**"Caveman mode doesn't activate in Cursor."** Cursor has no hook system, so caveman
needs a static rule file at `.cursor/rules/caveman.mdc` (see [Install](#install)).
Check with `ls .cursor/rules/caveman.mdc`. Absent → caveman is inactive and Diffwarden
shows the install tip instead of compact output.

**"It says I'm not authenticated."** Run `gh auth login`, then `gh auth status`
to confirm. For CI with no `gh` user, export a valid `GH_TOKEN`. If you are
logged in via `gh` but a stale `GH_TOKEN` is set, Diffwarden unsets it so your
user login wins.

**"It can't find a PR."** Make sure you're on the PR's branch, or pass the number/URL explicitly: `... on PR 123`.

**"It refuses to run on `main`/`master`."** By design. Switch to the PR's feature branch first.

**"It won't fix my failing CI by editing the workflow."** Also by design — it never weakens CI/tests to go green. Fix the real cause.

**"Will it merge my PR?"** No. Never. You merge.

**"Can it review a PR from a fork?"** It can review and (with `--post-review`) comment. It usually can't push fixes to a fork branch, so use `--no-push` / treat fixes as suggestions.

**"It stopped early."** It hit a safety stop (dirty worktree, ambiguous risk, head changed, max iterations). Read the report — it says why and what to do next.

## Contributing

Contributions welcome — fork, branch, PR.

```bash
# 1. Fork on GitHub, then:
git clone https://github.com/<you>/diffwarden
cd diffwarden
git checkout -b my-change

# 2. Make the change. Before pushing, run the same checks CI runs:
bash -n install.sh          # shell syntax
shellcheck install.sh       # shell lint
# if you bumped the version, confirm it matches in every file (see below)

# 3. Push to your fork and open a PR against main.
git push -u origin my-change
```

**Branch protection on `main`.** `main` is protected by repository rulesets —
plan your PR around them:

- **No direct pushes to `main`** — every change lands through a pull request,
  including the maintainer's. Pushing to `main` is rejected.
- **1 approving review required** before merge.
- **CI must pass** (`bash -n` + `shellcheck` on `install.sh`, plus a version-sync
  check). This is enforced for everyone — the maintainer can't merge red CI.
- **Squash merge only** — keeps `main` linear. Your PR's commits are squashed
  into one on merge, so a clean PR title is the commit message.
- **No force-push, no branch deletion** on `main`.

The maintainer may merge without a second reviewer (solo project) but is still
held to "PR required" and "CI green" — same as everyone else.

**Touching the skill or its version?** `SKILL.md` is the source of truth; if you
change it, update `README.md` and `CHANGELOG.md` to match. The version string is
duplicated across six places and must stay in sync (CI fails otherwise) — see
[`CLAUDE.md`](CLAUDE.md) for the exact list and the project's editing rules.

## Files

- `skills/diffwarden/SKILL.md` — the skill/playbook (the actual product).
- `skills/diffwarden/commands/` — optional `/dw` `/diffwarden` slash files for Claude Code and Cursor.
- `install.sh` — installer that detects agents and copies the skill + command files into place.
- `.github/workflows/ci.yml` — CI: shellchecks `install.sh` and enforces version sync.
- `README.md` — this guide.
- `CHANGELOG.md` — release notes.
- `CLAUDE.md` / `AGENTS.md` — agent guidance (`AGENTS.md` symlinks `CLAUDE.md`).
- `LICENSE` — MIT.
- `.gitignore` — local/editor/cache exclusions.

## Version

Current version: `v0.23.2`
