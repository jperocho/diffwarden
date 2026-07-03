# Diffwarden

[![version](https://img.shields.io/badge/version-0.27.2-blue.svg)](CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![CI](https://github.com/jperocho/diffwarden/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jperocho/diffwarden/actions/workflows/ci.yml)
[![skills.sh](https://img.shields.io/badge/skills.sh-diffwarden-black.svg)](https://www.skills.sh/jperocho/diffwarden/diffwarden)
[![Agent Trust Hub](https://img.shields.io/badge/Agent%20Trust%20Hub-pass-brightgreen.svg)](https://www.skills.sh/jperocho/diffwarden/diffwarden/security/agent-trust-hub)
[![Socket](https://img.shields.io/badge/Socket-pass-brightgreen.svg)](https://www.skills.sh/jperocho/diffwarden/diffwarden/security/socket)
[![Snyk](https://img.shields.io/badge/Snyk-warn-yellow.svg)](https://www.skills.sh/jperocho/diffwarden/diffwarden/security/snyk)

Independent PR guardian skill. You tell your coding agent "use diffwarden on this PR" and it reviews the pull request like a careful senior engineer: reads the diff, CI checks, and review comments; finds bugs and risks; fixes safe ones; verifies; and stops before doing anything dangerous.

It never auto-merges, never force-pushes, and never weakens your tests or CI to make a check go green.

## Contents

- [Command reference](#command-reference)
- [Workspace review (no git required)](#workspace-review-no-git-required)
- [Review uncommitted changes (no PR)](#review-uncommitted-changes-no-pr)
- [Auto-detected mode (code vs plan)](#auto-detected-mode-code-vs-plan)
- [Go review profile](#go-review-profile)
- [Web-augmented review (opt-in)](#web-augmented-review-opt-in)
- [Loop until merge-ready (c5/5)](#loop-until-merge-ready-c55)
- [Optional orchestration](#optional-orchestration)
- [What it actually does](#what-it-actually-does)
- [Is this for me?](#is-this-for-me)
- [Prerequisites (do this first)](#prerequisites-do-this-first)
- [Pi Agent](#pi-agent)
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

Invoke with `/diffwarden` (or the optional `/dw` alias). v0.27.2 uses five primary commands: `review`, `loop`, `status`, `comment`, and `help`. Target arg: `workspace` (current folder, git not required), a local target (`local`, `staged`), a PR (`#123`, full URL, or omit for current-branch PR), or a plan/docs file (`path/to/file.md`). Natural-language prompts still work — see [Slash commands](#slash-commands).

**What works out of the box:** once the skill is installed (see [Install](#install)), `/diffwarden` registers in **Claude Code** automatically (it matches the skill name). The shorthand `/dw` needs command files in Claude Code/Cursor. **Codex CLI is different** — see [Codex CLI](#codex-cli): use `$diffwarden` or `/skills`, not `/dw` or `/diffwarden`.

| Command | What it does |
|---------|--------------|
| `/diffwarden review [<target>]` | Read-only review + fix plan. No edits, commits, or push. Lean output by default. |
| `/diffwarden loop [<target>]` | Review → fix safe issues → verify → rescore until `c5/5`. Local edits only unless `--commit` or `--push`. |
| `/diffwarden status [<target>]` | Score/snapshot only (checks, confidence, blockers). |
| `/diffwarden comment [<pr>]` | Short PR review comment. Asks for explicit approval before posting. PR-only. |
| `/diffwarden help` | List commands. Bare `/diffwarden` = help. Use `/dw help --verbose` for advanced flags. |

**Targets:**

| Target | Meaning |
|--------|---------|
| `workspace` | Current folder — git not required (see [Workspace review](#workspace-review-no-git-required)) |
| `local` / `staged` | Git working tree or staged changes, no PR |
| `#123`, PR URL, or omitted | GitHub PR (current branch when omitted) |
| `path/to/file.md` | Plan, docs, guides, tutorials (see [Auto-detected mode](#auto-detected-mode-code-vs-plan)) |

| Flag | Effect |
|------|--------|
| `--mvp` | Stop loop at `c4/5` when only P3/info remains. |
| `--verbose` | Full detailed report (iterations, verification, changed files, risks, …). Off by default. |
| `--go` | Enable the [Go review profile](#go-review-profile) for code targets. Shorthand for `--lang go`. Auto-detected from `go.mod`, `.go` files, or CI. |
| `--lang <name>` | Enable a named language profile for code targets (`go` is currently supported). |
| `--orchestrate` | Split review and fix across configured models (see [Optional orchestration](#optional-orchestration)). Off by default. |
| `--commit` | Commit verified changes (git modes only, after verification). |
| `--push` | Commit + push verified changes (PR mode only, after PR head recheck). |
| `--security` | Security-focused review (auth, injection, SSRF, secrets, path traversal, crypto, data loss). |
| `--as-code` / `--as-plan` | Force code or plan/document mode for `review`/`loop`. |
| `--web` / `--research` | Opt into [web-augmented review](#web-augmented-review-opt-in). Per-finding consent. |
| `--reply` / `--resolve` | Reply on or resolve PR review threads (explicit approval required). |
| `--dry-run` | Review only; no edits (= `review`). |
| `--max N` | Loop iterations (default `3`, hard max `5`). |

**Compatibility aliases** (still work; not shown in short help):

| Alias | Equivalent |
|-------|------------|
| `fix` | `loop` |
| `prepare` | `loop --push` |
| `security` | `review --security` |
| `review-plan <file>` | `review <file> --as-plan` |
| `fix-plan <file>` | `loop <file> --as-plan` |

```text
/dw review workspace
/dw loop workspace
/dw loop #123 --commit
/dw loop #123 --push
/dw comment #123
/dw status
/dw help
/dw help --verbose
```

## Workspace review (no git required)

Use `workspace` to review the current folder when there is no git repo, no branch, detached HEAD, or no open PR. Diffwarden discovers files, detects the stack, and reviews high-signal code/config/tests/docs — no PR detection, no CI, no GitHub comments.

```text
/dw review workspace          # read-only workspace review
/dw loop workspace            # review + fix safe issues (backs up before editing)
/dw status workspace          # score only
```

Auto-fallback: when no explicit PR target is given and git/branch/PR is missing, Diffwarden falls back to workspace mode instead of blocking.

`loop workspace` creates a reversible baseline in `.diffwarden/backups/<timestamp>/` before the first edit. Workspace mode does not commit, push, or post PR comments. `--push` and `--commit` are rejected for `workspace`.

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
/dw loop local            # review + apply safe fixes (no commit/push unless --commit)
/dw review local --security   # security-focused pass on uncommitted changes
```

Valid with `review`, `loop`, and `status`. Everything that defines a
review still runs — classification, severity, confidence score, fix loop,
verification, security checklist. What's skipped (no PR exists): PR detection,
CI, review/issue comments, `comment`, and push. `loop local` edits the working tree only unless you pass `--commit`. `comment` and `--push` are rejected with a local target.

## Auto-detected mode (code vs plan)

`review` and `loop` work on **either** code or a plan/docs file.
Diffwarden classifies the *target* and runs the matching mode — you do
not pick a separate subcommand.

| Target | Detected mode |
|--------|---------------|
| `workspace` | code (folder scan, git optional) |
| `#123`, `123`, full PR URL, `current`, or omitted | code |
| `local`, `staged`, `worktree` | code |
| a single prose `.md` plan/docs file | document/plan |
| `--as-code` flag | code (forced) |
| `--as-plan` flag | plan (forced) |
| **mixed** signals (e.g. a PR *and* a `.md` plan) | **asks you; default code** |

```text
/dw review #123            # PR review
/dw review                 # current branch PR or git-local/workspace fallback
/dw review workspace       # folder review, no git required
/dw review docs/plan.md    # document/plan review
/dw review docs/plan.md --as-code   # force code review of the file
/dw loop #123              # PR fix loop
/dw loop docs/plan.md      # revise document in place (backs up to <file>.orig)
/dw loop docs/plan.md --as-plan     # explicit document mode
```

`--as-code` / `--as-plan` override the detector; on a mix of signals Diffwarden
**asks first** (defaulting to code only if you don't choose) — it never silently
guesses. Document mode never touches a PR or git: `review` is read-only;
`loop` revises only the target document (backing up to `<file>.orig`) and
never commits or pushes unless you pass `--commit` in a git context. `comment` is PR-only.

> The older `review-plan` / `fix-plan` names still work as **hidden back-compat
> aliases** (equivalent to `review` / `loop <file> --as-plan`), but `review` /
> `loop` on a `.md` file is the way to invoke document mode now.

## Go review profile

Diffwarden has a built-in Go/Golang review profile for code targets, activated with `--go` (or `--lang go`). Auto-detection kicks in when `go.mod`, `.go` files, or Go-related CI steps are present — no flag needed for Go projects.

```text
/dw review                 # auto-detect Go when current PR/local/workspace is Go
/dw review workspace --go  # force Go profile on workspace scan
/dw review local --lang go # force Go profile on uncommitted changes
/dw loop staged --go       # fix safe Go issues in staged diff
/dw review #123 --go --security
/dw loop #123 --go --mvp
$diffwarden review local --lang go   # Codex CLI form
```

Use `--go` for brevity or `--lang go` for explicit language-profile syntax; they are equivalent. Valid code targets are PR refs/URLs/current branch, `local`, `staged`, `worktree`, and `workspace`.

When the Go profile is active on a code target, the mode banner adds a language line:

```text
detected: code review
language: go
```

**What the Go profile checks:**

- `gofmt` formatting, `go vet` issues, test failures
- Race conditions, goroutine leaks, channel misuse, unsafe shared state
- Context propagation and cancellation
- Missing `defer rows.Close()` / `resp.Body.Close()`
- Error handling anti-patterns (ignored errors, sentinel error misuse)
- Nil pointer risks, interface nil traps
- Dependency risks in `go.mod` / `go.sum`
- Vulnerable dependencies, hardcoded secrets
- Path traversal, command injection, SQL injection, SSRF
- Insecure crypto (`math/rand` for secrets, MD5/SHA1 for security use)
- HTTP server timeout misconfiguration, missing request size limits
- Missing authz/ownership checks in handlers and services

**Deterministic tools first:** when available, `go vet`, `gofmt`, `go test`, and optional tools
(`golangci-lint`, `govulncheck`, `gosec`, `staticcheck`) are run first. AI review
then interprets the results and checks issues tools commonly miss (logic bugs,
auth gaps, concurrency patterns, design risks).

**Optional tools skipped gracefully:** if `golangci-lint` or `govulncheck` are not installed,
the review reports `verify: skipped — command not found` and continues. Missing optional
tools do not block the review or lower the confidence score on their own.

Document reviews stay text-only: no Go auto-detection, and explicit `--go` / `--lang` on a document is rejected.

```text
/dw review docs/plan.md --go       # rejected — document mode
/dw loop README.md --lang go       # rejected — document mode
/dw review local --lang rust       # rejected — unsupported profile
```

Unknown `--lang` names are rejected; `go` is the only supported profile now.

**No network access** unless `--web` is explicitly passed and you approve each search.

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

Valid on `review`, `loop`, and `review --security` (code targets, including
`local` / `staged` / `workspace`), and compatible with `--dry-run`.
Rejected on `status` (snapshot only) and on document mode (`--as-plan`
or a `.md` docs target) — document critique grounds against your repo, not the web.

```text
/dw review #123 --web      # asks [y/N] before grounding any uncertain finding
/dw loop --web --security  # security run reads raw; web grounding still per-finding gated
```

## Loop until merge-ready (c5/5)

`loop` is the primary review-fix-verify command. Each iteration: collect evidence → classify top blocker → compute confidence → fix safe scoped issue → verify → rescore. Stops at **c5/5**, `--mvp` at **c4/5**, or a safety stop.

### Lean output (default)

Loop prints one line per iteration, then final `Status:` and `Level:` lines — no long evidence blocks unless `--verbose`:

```text
c2/5 P1 src/auth.ts:44 — missing ownership check
c3/5 P2 tests missing for changed branch
c4/5 mvp-ready — only P3/info remains
c5/5 clean

Status: ready
Level: 5/5
```

Every final review ends with `Status:` then `Level:`. Review output is also lean by default:

```text
Findings:
- P1 src/auth.ts:44 — missing ownership check
- P2 tests/auth.test.ts — missing coverage for denied update

Status: not-ready
Level: 2/5
```

Use `--verbose` for the full report (iterations, verification, changed files, risks, next action, how to test).

### Commands

| Goal | Command |
|------|---------|
| Loop locally (no commit/push) | `/dw loop` or `/dw loop --max 5` |
| Loop + commit | `/dw loop --commit` |
| Loop + commit + push (PR only) | `/dw loop --push` or `/dw loop #123 --push` |
| Check score only | `/dw status` |
| Stop at MVP (c4/5) | `/dw loop --mvp` |
| Post short PR comment | `/dw comment #123` |

Natural language: `Use diffwarden on the current PR --max-iterations 5`

Default **3** iterations; hard max **5** unless you explicitly ask for more in chat.

### What c5/5 means

All must be true (scope-dependent — PR vs local vs workspace):

- Required CI checks pass (PR mode) or grounded local verification passes
- No actionable findings remain
- No open P0/P1/security issue
- PR description adequate (PR mode) or document/workspace ready

Score is recomputed from evidence every iteration. **c5/5 does not auto-merge** — you merge.

### Confidence scale (short)

| Score | Meaning |
|-------|---------|
| `c5/5` | Clean / merge-ready (loop stops) |
| `c4/5` | MVP-ready — only P3 / informational items left (`--mvp` stops here) |
| `c3/5` | P2 issues or missing targeted test / verification |
| `c2/5` | P1 issue or failing required check |
| `c1/5` | P0, security, or hard build failure |

Safety caps: unresolved P0/security → max `1/5`; failing required check → max `2/5`;
needs-user-decision → max `3/5` until you decide.

### Evidence-based findings

- Actionable findings need **anchor + quote** — not model guesswork.
- Anchors: `file:line`, check name, PR field, or comment/thread id.
- Fix plans: only diff/read files; verify commands must exist in manifests.
- Verification is built into `loop` (no `--verify` flag on `review`).
- `--verbose` loop adds structured `verify: pass|fail|skipped` reporting.

### When it stops before c5/5

| Reason | What to do |
|--------|------------|
| Hit `--max 5` | Run again: `/dw loop --max 5` |
| `--mvp` and c4/5 | Done for MVP — merge or continue without `--mvp` |
| Needs user decision (API, product, migration…) | Answer in chat, re-run |
| Same finding repeats | Agent stops — fix root cause manually |
| CI still pending | Wait for green, then `/dw status` |
| Dirty unrelated files | Clean worktree or stash first |

### Example workflow

```text
/dw status
/dw loop --max 5
/dw loop #123 --push
/dw comment #123
```

## Optional orchestration

Diffwarden can optionally split review and fix work across different models using
`--orchestrate`. This is off by default. See
[docs/orchestration.md](docs/orchestration.md).

## What it actually does

This repo is **not an app**. It is one markdown playbook (`skills/diffwarden/SKILL.md`) that teaches an AI coding agent (Claude Code, Copilot CLI, Cursor, etc.) a safe, repeatable way to babysit a pull request.

Given a PR, the agent:

1. Checks your environment is safe to work in (git repo, logged into GitHub, right branch).
2. Reads everything: the diff, CI status, inline review comments, bot comments.
3. Auto-detects the language (Go if `go.mod` / `.go` files / Go CI steps are found) and
   activates the matching review profile — or uses `--go` / `--lang go` explicitly.
4. Sorts findings into: must-fix now, FYI, already fixed, or "ask the human".
   Actionable items need anchor + quote (file/line, check, PR field, or comment).
5. Ranks by severity (P0 security/data-loss down to P3 polish).
6. Writes a small fix plan, applies safe fixes, and runs discovered tests/linters
   to prove they work (`loop` only — `review` is read-only).
7. Optionally posts the review on GitHub or commits fixes — only if you allow it.
8. Loops until the PR is merge-ready, blocked, or it needs your decision.

## Is this for me?

Use it if you want to:

- check a PR before merging it
- get failing CI checks fixed safely
- review a teammate's PR and leave comments on GitHub
- do a focused security pass on changed code

Don't use it for: deploying to production, auto-merging, rewriting git history, or large refactors unrelated to the PR.

## Prerequisites (do this first)

You need a coding agent that can read skills and run shell commands. Examples: Claude Code, Codex, GitHub Copilot CLI, Cursor, OpenCode, Pi Agent. The installer targets Claude Code, Codex, Cursor, and Pi directly; any other skill-loading agent works via manual copy ([Install](#install) Option C/D).

**For PR review** you also need `git`, GitHub CLI (`gh`), and a logged-in GitHub session:

```bash
git --version
gh --version
gh auth status        # should say "Logged in to github.com"
gh auth login         # run this if it doesn't
```

**For workspace or document review** git and `gh` are optional. Diffwarden falls back to workspace mode when git/branch/PR is unavailable.

Optional: export `GH_TOKEN` (or `GITHUB_TOKEN`) for CI/automation when `gh auth
login` is not available. Diffwarden tries `gh auth status` first; if you are
logged in, it ignores env tokens for that session so `gh` uses your user. With
no active user, it validates env tokens with `gh api user`. It never searches
files or config for tokens.

## Pi Agent

Diffwarden can be used with Pi Agent three ways: installer/manual skill copy, prompt templates, or optional Pi package extension.

Diffwarden core behavior stays agent-neutral. The extension only adds native `/dw` and `/diffwarden` commands that forward to `/skill:diffwarden`, plus bundled skill discovery.

### Pi package extension

> Security: Pi extensions run with full local permissions. Review `extensions/diffwarden/index.ts` before installing.

```bash
pi install npm:pi-diffwarden@0.27.2      # global
pi install -l npm:pi-diffwarden@0.27.2   # project

# Git source also works:
pi install git:github.com/jperocho/diffwarden@v0.27.2
```

The package loads `extensions/diffwarden/index.ts`, which discovers `skills/diffwarden/SKILL.md` from this repo. Restart Pi Agent or run `/reload` after installing.

### Manual install

Copy the Diffwarden skill into one of Pi Agent's skill locations:

```bash
# project scope, loaded after the project is trusted
mkdir -p .pi/skills/diffwarden
cp skills/diffwarden/SKILL.md .pi/skills/diffwarden/SKILL.md

# global scope
mkdir -p ~/.pi/agent/skills/diffwarden
cp skills/diffwarden/SKILL.md ~/.pi/agent/skills/diffwarden/SKILL.md
```

Pi also discovers skills from `.agents/skills/` and `~/.agents/skills/`, so the Codex-compatible install path works in Pi too.

Optional `/dw` and `/diffwarden` aliases can be installed as Pi prompt templates when you do not use the extension package:

```bash
# project scope
mkdir -p .pi/prompts
cp skills/diffwarden/prompts/dw.md .pi/prompts/dw.md
cp skills/diffwarden/prompts/diffwarden.md .pi/prompts/diffwarden.md

# global scope
mkdir -p ~/.pi/agent/prompts
cp skills/diffwarden/prompts/dw.md ~/.pi/agent/prompts/dw.md
cp skills/diffwarden/prompts/diffwarden.md ~/.pi/agent/prompts/diffwarden.md
```

The prompt templates must pass arguments through with `$ARGUMENTS` so `/dw loop workspace` expands to a Diffwarden invocation with `loop workspace` intact.

Restart Pi Agent or run `/reload` after installing. Without prompt templates or the extension, invoke the skill with `/skill:diffwarden` or plain chat.

### Installer

```bash
./install.sh --pi --project
./install.sh --pi --global
./install.sh --pi --pi-root ~/.pi/agent --global
./install.sh --pi --pi-root ./.pi --project
./install.sh --pi --dry-run
```

### Usage

```text
/dw review workspace
/dw loop workspace
/dw review
/dw loop
/diffwarden review
/diffwarden loop
/skill:diffwarden loop workspace
```

### Extension behavior

The extension registers native `/dw` and `/diffwarden` commands, offers basic argument completions, and sends `/skill:diffwarden <args>` to the agent. It does not add tool interception, auto-merge, auto-push, file writes, or background processes.

## Install

**Global install is recommended** — Diffwarden is a reusable reviewer/fixer that should be available in every workspace. Project install is still supported for team/repo-specific distribution.

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
where to install (global recommended), copies the skill + command files into the right places,
skips files already up to date, and never overwrites a changed file without
asking.

> **Security — inspect before you run.** Diffwarden is a safety tool; don't
> pipe a script straight into a shell on its word. Download it, read it, then
> run it. The installer pins to a release tag, uses HTTPS only, never uses
> `sudo`, and only writes under `.claude/`, `.cursor/`, `.agents/`, Pi roots
> (`skills/` + `prompts/` only), and optional `~/.config/diffwarden/` when you
> confirm orchestration defaults.

```bash
# Recommended: download → read → run
curl -fsSLO https://raw.githubusercontent.com/jperocho/diffwarden/v0.27.2/install.sh
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
./install.sh --pi --global        # Pi Agent, all projects on this machine
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
/diffwarden loop
/diffwarden loop #123 --push
/diffwarden comment #123
/dw status
/dw loop workspace
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
| Explicit invocation | `$diffwarden review`, `$diffwarden loop workspace` |
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
$diffwarden loop workspace
$diffwarden loop #123 --push
$diffwarden comment #123
$diffwarden status
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
5. When ready to let it act:

   ```text
   /diffwarden loop
   ```

   Or with explicit push on a PR:

   ```text
   /diffwarden loop #123 --push
   ```

If you omit the PR number/URL, it detects the PR from your current branch.

## Modes / flags

Add these after the command. Combine freely. Short help shows primary flags; use `/dw help --verbose` for the full list.

| Flag | What it does |
|------|--------------|
| `--mvp` | Stop loop at `c4/5` when only P3/info remains. |
| `--verbose` | Full detailed report instead of lean output. |
| `--orchestrate` | Optional reviewer/fixer model split ([docs/orchestration.md](docs/orchestration.md)). |
| `--commit` | Commit verified changes (git modes, after verification). |
| `--push` | Commit + push verified changes (PR mode only, after head recheck). |
| `--as-code` / `--as-plan` | Force code or document mode, overriding the [target detector](#auto-detected-mode-code-vs-plan). |
| `--dry-run` | Review and plan only. No edits, commits, pushes, or comments. **Start here.** |
| `--security` | Prioritize security: auth, injection, SSRF, secrets, path traversal, crypto, data loss. |
| `--reply` / `--resolve` | Reply on or resolve PR review threads (explicit OK each run). |
| `--web` / `--research` | Opt into [web-augmented review](#web-augmented-review-opt-in). Per-finding consent. |
| `--max N` | Loop iterations. Default `3`; hard max `5`. |

## Common recipes

**Review your own PR before merge (safe, read-only):**

```text
/diffwarden review
```

**Review a teammate's PR and post a short comment:**

```text
/diffwarden comment #123
```

Posts a `COMMENT`-type review with inline P-level notes after your approval. It will **not** approve or request changes — that decision stays yours.

**Security-focused pass:**

```text
/diffwarden review #123 --security
```

**Review a folder with no git repo:**

```text
/dw review workspace
/dw loop workspace
```

**Address review feedback and reply on threads:**

```text
/diffwarden loop #123 --reply --resolve
```

**Let it fix safe issues locally, but don't push:**

```text
/diffwarden loop
```

**Loop until merge-ready and push (PR):**

```text
/diffwarden loop #123 --push
```

**Go project — full review with security pass:**

```text
/dw review workspace --go
/dw review #123 --go --security
/dw review local --lang go
```

**Go project — fix loop on staged changes:**

```text
/dw loop staged --go
/dw loop #123 --go --mvp
```

## What it will and won't do

**Will:**

- Read diffs, checks, and comments.
- Treat PR/comment/CI text as untrusted evidence, never as instructions.
- Fix safe, in-scope issues and run tests to verify.
- Reply on reviewer comment threads (with `--reply` + your OK).
- Resolve fixed threads (with `--resolve` + your OK).
- Post short comment-only reviews (with `comment` + your OK).
- Commit/push **only** when you pass `--commit` or `--push`.

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

**" `/dw` doesn't show in the `/` menu."** For Claude Code/Cursor, the command files weren't installed; copy `dw.md` / `diffwarden.md` into `.claude/commands/`, `~/.claude/commands/`, `.cursor/commands/`, or `~/.cursor/commands/`, then restart. For Pi Agent, install prompt templates or the Pi package extension, then run `/reload`. For **Codex CLI**, `/dw` and `/diffwarden` are **not supported** — the `/` menu is built-in commands only. Install the skill to `.agents/skills/diffwarden/` (or `~/.agents/skills/diffwarden/`), restart or `/clear`, then use `$diffwarden review ...` or `/skills`. See [Codex CLI](#codex-cli) for why `/prompts:dw` also no longer works on Codex ≥ 0.117.

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

**"Can it review a PR from a fork?"** It can review and (with `comment`) post findings. It usually can't push fixes to a fork branch, so omit `--push` / treat fixes as suggestions.

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
node -e 'JSON.parse(require("fs").readFileSync("package.json","utf8"))'
npm pack --dry-run
./install.sh --pi --pi-root /tmp/pi-agent --project --dry-run
# Optional local Pi smoke, when pi is installed:
pi -e ./extensions/diffwarden/index.ts --help
# if you bumped the version, confirm it matches in every file (see below)

# 3. Push to your fork and open a PR against main.
git push -u origin my-change
```

**Branch protection on `main`.** `main` is protected by repository rulesets —
plan your PR around them:

- **No direct pushes to `main`** — every change lands through a pull request,
  including the maintainer's. Pushing to `main` is rejected.
- **1 approving review required** before merge.
- **CI must pass** (`bash -n` + `shellcheck` on `install.sh`, Pi installer
  dry-runs, Pi package static checks, `npm pack --dry-run`, plus a version-sync
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
- `skills/diffwarden/prompts/` — Pi Agent prompt templates for `/dw` and `/diffwarden`.
- `extensions/diffwarden/index.ts` — optional Pi extension command wrapper and resource discovery.
- `package.json` — Pi/npm package manifest for installing the extension from npm, git, or local paths.
- `docs/orchestration.md` — optional model orchestration guide.
- `install.sh` — installer that detects agents and copies the skill + command files into place.
- `.github/workflows/ci.yml` — CI: shellchecks `install.sh` and enforces version sync.
- `README.md` — this guide.
- `CHANGELOG.md` — release notes.
- `CLAUDE.md` / `AGENTS.md` — agent guidance (`AGENTS.md` symlinks `CLAUDE.md`).
- `LICENSE` — MIT.
- `.gitignore` — local/editor/cache exclusions.

## Version

Current version: `v0.27.2`
