---
name: diffwarden
description: "Use when preparing a pull request for merge: inspect diffs, collect checks and review comments, classify findings, fix safe issues, verify, and loop until merge-ready. Supports /diffwarden and /dw slash commands."
version: 0.10.1
author: jperocho
license: MIT
metadata:
  tags: [code-review, pull-request, ci, quality-gate, automation, github, agent-skill]
  related_skills: [github-pr-workflow, github-code-review, systematic-debugging, test-driven-development, requesting-code-review]
---

# Diffwarden

## Overview

Diffwarden is an independent PR guardian. It reviews the current pull request from the outside: diff, CI, review threads, bot comments, human comments, tests, and risky code paths. It then classifies findings, plans scoped fixes, verifies changes, and loops until the PR is merge-ready or blocked.

Core loop:

```text
preflight -> detect PR -> collect evidence -> classify -> plan fixes -> apply safe fixes -> verify -> optional commit/push -> optional thread replies/resolve -> optional post-review -> re-check -> report
```

Default stance: conservative. Diffwarden prepares a PR for merge. It does not auto-merge.

## Caveman Mode (token savings)

Diffwarden is verbose by design: it reads diffs, CI logs, and review threads,
then loops. The optional `caveman` skill compresses agent output ~75% with no
loss of technical substance — a good fit for long Diffwarden runs.

At the start of every invocation, check whether the `caveman` skill is
available (look for a `caveman` / `caveman:caveman` skill, or an active
"CAVEMAN MODE" session directive):

- **Caveman available** → run Diffwarden in caveman mode: compact, high-signal,
  bullets over prose. Keep all paths, commands, errors, verification results,
  risks, and next actions exact. Caveman's own safety carve-outs still apply
  (security warnings, irreversible-action confirmations, and commits/PRs stay in
  normal prose).
- **Caveman not installed** → emit this one-line suggestion once per run, then
  continue normally:

  ```text
  Tip: Diffwarden works better with the `caveman` skill — ~75% fewer output
  tokens on these long review loops. Install the caveman skill/plugin to enable.
  ```

  Do not block, nag, or repeat the tip. Diffwarden runs fully without caveman.

This is an output-style choice only. It never changes classification, fix
scope, safety gates, or the loop algorithm.

## When to Use

Use Diffwarden when the user asks to:

- invoke a `/diffwarden` or `/dw` slash command (see Slash Commands)
- check a PR before merge
- address review feedback
- fix failing PR checks
- run a review-fix-verify loop
- prepare a PR for human approval
- perform a security/quality pass on changed code
- verify whether a PR is merge-ready

Do not use Diffwarden for:

- production deployment
- automatic merging
- bypassing or weakening CI
- broad refactors outside PR scope
- destructive history rewrite
- non-GitHub workflows until adapters are added

## Inputs

Supported now:

- PR number or URL, optional. If omitted, detect from current branch.
- `--dry-run`, optional. Plan only; no edits, commits, pushes, or comment resolution.
- `--no-push`, optional. Local fixes only.
- `--post-review`, optional. Post findings to the PR as a GitHub review of type `COMMENT` (and optional inline comments). Off by default; requires explicit user authorization each run. Never approves, requests changes, or merges.
- `--reply-comments`, optional. Post threaded replies on existing inline review comments after fixes (see Replying to Review Comments). Off by default; requires explicit user authorization each run.
- `--resolve-replied`, optional. With `--reply-comments`, resolve review threads where reply type is `fixed` or `already-addressed`. Off by default; requires explicit user authorization. Never resolve human threads without both flags and authorization.
- `--security-focus`, optional. Prioritize auth, input validation, secrets, data loss, SSRF, injection, path traversal, crypto, and logging leaks.
- `--max-iterations N`, optional. Default `3`; hard max `5` unless the user explicitly asks otherwise.
- Slash commands `/diffwarden` and `/dw`, optional. See Slash Commands.

Initial platform:

- GitHub via `gh` CLI.

Future platforms:

- GitLab via `glab`.
- Perforce via `p4`.
- Greptile MCP adapter.

## Slash Commands

When the user message starts with `/diffwarden` or `/dw`, treat it as a
Diffwarden invocation. Parse the command, expand to the skill flags below, then
run the full Diffwarden loop. Do not ask the user to rephrase unless parsing
fails or flags contradict each other.

**Cursor `/` menu:** optional Cursor-only step. Copy `skills/diffwarden/commands/*.md`
to `.cursor/commands/` or `~/.cursor/commands/`. Without those files, the user
can still type `/dw review` as plain chat text when this skill is loaded. Not
required for non-Cursor agents.

### Grammar

```text
/diffwarden <subcommand> [<pr>] [flags]
/dw <subcommand> [<pr>] [flags]

<subcommand>  review | fix | prepare | security | status | help
<pr>          #123 | 123 | current | https://github.com/owner/repo/pull/N | (omit = current branch PR)
<flags>       --comment | --reply | --resolve | --security | --push | --max N | --dry-run
```

Bare `/diffwarden` or `/dw` with no subcommand → same as `help`.

### Subcommands

| Subcommand | Skill flags | Behavior |
|------------|-------------|----------|
| `review` | `--dry-run` | Read-only: collect evidence, classify, plan fixes. No edits, commits, push, or comment resolution. |
| `fix` | `--no-push` | Review → fix safe issues → verify locally. No push unless `--push`. |
| `prepare` | *(none — full prep authorized)* | Review → fix → verify → commit/push when verified. |
| `security` | `--dry-run --security-focus` | Read-only security-focused pass. |
| `status` | `--dry-run` | Quick merge-readiness snapshot: status, confidence score, blocking findings only — no fix plan. |
| `help` | — | Print the slash-command reference; do not run the loop. |

### Flag mapping

| Slash flag | Skill flag |
|------------|------------|
| `--comment` | `--post-review` (requires explicit user authorization before posting) |
| `--reply` | `--reply-comments` (requires explicit user authorization before posting) |
| `--resolve` | `--resolve-replied` (requires `--reply` and explicit user authorization) |
| `--security` | `--security-focus` |
| `--push` | omit `--no-push` on `fix` only (allows push after verification) |
| `--max N` | `--max-iterations N` |
| `--dry-run` | `--dry-run` |

Default iterations: `3`. Hard max: `5` unless the user explicitly overrides in chat.

### PR resolution

1. Full GitHub PR URL → use as-is.
2. `#123` or `123` → resolve URL:

   ```bash
   gh pr view 123 --json url -q .url
   ```

3. `current` or omitted → detect from branch:

   ```bash
   gh pr view --json url -q .url
   ```

If resolution fails, halt with a `blocked` report; do not guess.

### Expansion examples

```text
/diffwarden review #123
→ Use diffwarden on PR <resolved-url> --dry-run

/diffwarden review #123 --comment
→ Use diffwarden on PR <resolved-url> --dry-run --post-review

/diffwarden fix
→ Use diffwarden on the current PR --no-push

/diffwarden fix #123 --security --max 5
→ Use diffwarden on PR <resolved-url> --no-push --security-focus --max-iterations 5

/diffwarden prepare #123 --comment
→ Use diffwarden on PR <resolved-url> --post-review

/diffwarden fix #123 --reply
→ Use diffwarden on PR <resolved-url> --no-push --reply-comments

/diffwarden prepare #123 --reply --resolve
→ Use diffwarden on PR <resolved-url> --reply-comments --resolve-replied

/diffwarden security #123 --comment
→ Use diffwarden on PR <resolved-url> --dry-run --security-focus --post-review

/diffwarden status
→ Use diffwarden on the current PR --dry-run. Report Diffwarden version (frontmatter `version:`), status, confidence score, and blocking findings only — no fix plan.
```

### Invalid combinations

Reject with a one-line reason; suggest the correct command:

| Invalid | Why | Use instead |
|---------|-----|-------------|
| `fix … --comment` | Ambiguous: new review vs thread reply | `review … --comment` or `fix … --reply` |
| `review … --reply` | Review is read-only | `fix … --reply` or `prepare … --reply` |
| `* --resolve` without `--reply` | Resolve needs a posted reply first | add `--reply` |
| `review … --push` | Review is read-only | `prepare` |
| `status … --comment` | Status is snapshot only | `review … --comment` |
| `prepare … --dry-run` | Contradiction | `review` |
| `fix … --push` on a fork PR | Cannot push to fork head | `fix …` (local only) or `review … --comment` |
| `* --max N` where N > 5 | Hard cap | `--max 5` or ask user to override explicitly |

### Help output

When subcommand is `help` or the message is bare `/diffwarden` / `/dw`, reply with:

```text
Diffwarden slash commands (/diffwarden or /dw):

  review [<pr>] [--comment] [--security] [--max N]   read-only review (default: no PR comments)
  fix [<pr>] [--reply] [--resolve] [--security] [--max N] [--push]
                                                     apply fixes locally (default: no push)
  prepare [<pr>] [--comment] [--reply] [--resolve] [--security] [--max N]
                                                     fix, verify, commit, and push
  security [<pr>] [--comment] [--max N]              security-focused read-only review
  status [<pr>]                                      quick merge-readiness snapshot
  help                                               this message

Flags: --comment = post new review; --reply = reply on existing review threads;
       --resolve = resolve threads after fixed replies (needs --reply + your OK)

<pr>: #123, 123, current, full PR URL, or omit for current branch PR
```

Then stop; do not run the loop.

## External Agent Protocol

This section is optional. Use it only when the user has external coding-agent
CLIs available and wants help executing Diffwarden work. The "Caveman mode"
prefix below is an output-formatting directive for the helper agent — it
constrains response style and scope. It is not an instruction-injection,
safety-override, or jailbreak payload, and it does not grant the helper any
authority. External agents stay subordinate to the rules at the end of this
section: they are never trusted on self-report and never commit, push, merge,
or resolve comments without explicit user authorization.

When using external coding agents to help execute Diffwarden-related implementation or review work, prepend Caveman mode before task instructions.

Required prompt prefix:

```text
CAVEMAN MODE:
- Compact, high-signal output.
- Bullets over prose.
- No filler.
- Preserve exact paths, commands, errors, verification results, risks, and next actions.
- Do not make broad changes beyond requested scope.
```

Preferred helper agents when available:

- Claude Code CLI: primary implementation/review helper.
- Copilot CLI: secondary implementation/review helper.
- The primary agent remains orchestrator and verifier.

Preflight before invoking external agents:

```bash
command -v claude || true
command -v copilot || true
claude --version || true
copilot --version || true
```

Rules:

1. Do not trust external-agent self-reports.
2. Verify all claimed changes with file reads, `git diff`, and commands.
3. If agent outputs conflict, prefer verified evidence over claims.
4. External agents must not commit, push, merge, or resolve comments unless explicitly authorized.

## Preflight

Preflight is a hard gate, not advice. Run it before any edits and at the start
of every loop iteration. If any check fails, **halt immediately**: do not
classify, plan, edit, commit, push, or post. Emit a `blocked` report naming the
failed check and the exact command output, then stop.

The gate runs in two phases. Phase 1 needs no PR context and runs first. Phase 2
runs after PR detection (see "GitHub PR Detection") and checks the working tree
against the live PR. Both exit non-zero on failure so the result is
machine-checkable, not a judgment call.

Both phases honor `REVIEW_ONLY`. Set `REVIEW_ONLY=1` for runs that never touch
the working tree — `review`, `status`, `security`, any `--dry-run` run, and
`--post-review` on a PR you do not own. Set `REVIEW_ONLY=0` (default) for
local-edit runs (`fix`, `prepare`, or anything that may edit/commit/push). In
review-only mode the gate skips working-tree checks (protected-branch,
base-branch, head-drift) because the run reads everything from the PR head SHA
via the API — this is what lets a reviewer on another machine, sitting on their
own default branch without the PR checked out, review the PR without a spurious
halt.

### Phase 1 — environment gate

```bash
set -u
fail() { echo "PREFLIGHT FAIL: $*" >&2; exit 1; }

# In a git repo?
git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repo"

# GitHub CLI present?
command -v gh >/dev/null 2>&1 || fail "gh CLI not installed"

# GitHub auth: gh user login first; env token only if no active user (see GitHub Authentication).
if gh auth status >/dev/null 2>&1; then
  if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "PREFLIGHT: gh user login active; ignoring GH_TOKEN/GITHUB_TOKEN this session" >&2
    unset GH_TOKEN GITHUB_TOKEN
  fi
  echo "gh auth: user login ok"
elif [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  if gh api user -q .login >/dev/null 2>&1; then
    echo "gh auth: env token ok"
  else
    unset GH_TOKEN GITHUB_TOKEN
    fail "invalid GH_TOKEN/GITHUB_TOKEN and no gh user login (gh auth login)"
  fi
else
  fail "gh not authenticated (gh auth login or export GH_TOKEN)"
fi

# Remote configured?
git remote -v | grep -q . || fail "no git remote configured"

# Not on a protected/base branch? Only matters when we may edit/commit/push.
# Review-only runs (review/status/security, any --dry-run, --post-review on a PR
# you do not own) never touch the tree, so sitting on main is fine — a reviewer
# on another machine is normally on their default branch.
REVIEW_ONLY="${REVIEW_ONLY:-0}"
BR="$(git branch --show-current)"
if [ "$REVIEW_ONLY" != "1" ]; then
  case "$BR" in
    main|master|trunk|develop) fail "on protected branch: $BR" ;;
  esac
fi

# Capture state for later staleness checks.
HEAD_SHA="$(git rev-parse HEAD)"
echo "preflight ok: review_only=$REVIEW_ONLY branch=$BR head=$HEAD_SHA"
git status --short
```

Phase 1 covers the environment. The PR-context checks (base branch, open state,
external head drift) are machine-checked in Phase 2 below, once the PR is known.

### Phase 2 — PR-context gate

The gate has two modes. **Local-edit mode** (`fix`, `prepare`, or any run that
may edit, commit, or push the working tree) requires the local checkout to match
the PR head — local changes are meaningless if they sit on a different commit.
**Review-only mode** (`review`, `status`, `security`, any `--dry-run` run, and
`--post-review` on a PR you do not own) never touches the working tree: it reads
all evidence from the PR head SHA via the API, so it does **not** require the PR
branch to be checked out locally. Requiring a local checkout there is what makes
a reviewer on another machine spuriously halt before fetching anything.

Set `REVIEW_ONLY=1` for review-only runs, else `REVIEW_ONLY=0`. Run after PR
detection, passing the resolved PR number. Reuses a single `gh` fetch; no `jq`
dependency:

```bash
set -u
PR="$1"   # resolved PR number from detection step
REVIEW_ONLY="${REVIEW_ONLY:-0}"
fail() { echo "PR-GATE FAIL: $*" >&2; exit 1; }

read -r STATE BASE RHEAD < <(gh pr view "$PR" --repo "$OWNER/$REPO" \
  --json state,baseRefName,headRefOid \
  -q '[.state, .baseRefName, .headRefOid] | @tsv') || fail "cannot fetch PR $PR"

[ "$STATE" = "OPEN" ] || fail "PR not open: $STATE"                      # closed/merged

if [ "$REVIEW_ONLY" = "1" ]; then
  # No local working tree involved. Pin the PR head SHA as the canonical
  # reference for all evidence collection and posting; skip local checks.
  echo "pr-gate ok (review-only): state=$STATE base=$BASE head=$RHEAD"
else
  [ "$(git branch --show-current)" != "$BASE" ] || fail "on PR base branch: $BASE"
  [ "$(git rev-parse HEAD)" = "$RHEAD" ] || fail "head drift: local != PR head ($RHEAD)"  # external push
  echo "pr-gate ok (local-edit): state=$STATE base=$BASE head=$RHEAD"
fi
```

In review-only mode, use `$RHEAD` (the PR head SHA from `gh`) as the reference
commit for diffs, comment anchoring, and post-review head checks — not local
`git rev-parse HEAD`. The dirty-worktree rule below applies only to local-edit
mode; review-only runs ignore working-tree state entirely.

The only check that stays a judgment call is **dirty-file relevance** — a script
can see that files are dirty, but not whether they belong to this fix.

Dirty worktree rule:

- If dirty files are unrelated to the PR fix, stop and ask.
- If dirty files are expected current-task edits, record them before continuing.

Never proceed past a failed gate by "fixing" the environment silently (e.g.
stashing user changes, switching branches) without explicit user approval.
Exception: unsetting `GH_TOKEN` / `GITHUB_TOKEN` (invalid token, or to prefer an
active `gh` user login over env) is allowed (see GitHub Authentication).

## GitHub Authentication

`gh` honors `GH_TOKEN` and `GITHUB_TOKEN` when set — they override keyring login.
Diffwarden prefers `gh auth status` (user/keyring login via `gh auth login`).
Use env tokens only when no active `gh` user. Never mix invalid env token with
login silently — validate first.

Rules:

- Prefer `gh auth status` / `gh auth login` for interactive use.
- Use env tokens **only** when no active `gh` user, and only if already exported
  in the shell. Do **not** search `.env`, config files, credential stores, git
  config, or the filesystem for tokens.
- When user login is active but env tokens are set, `unset GH_TOKEN GITHUB_TOKEN`
  for the session so `gh` uses the logged-in user (not the env override).
- Never echo, log, commit, or post token values.
- Re-check auth at the start of each loop iteration (same resolution order).
- If env token validation fails, `unset` both vars and halt with `blocked`; do
  not fall back to keyring in the same pass unless `gh auth status` succeeds.
- Do not halt solely because `GH_TOKEN` is unset when `gh auth status` succeeds.

Validate env token (no output on success; only after step 1 fails):

```bash
gh api user -q .login >/dev/null 2>&1
```

Safe resolution order:

1. `gh auth status` — if active user, `unset GH_TOKEN GITHUB_TOKEN` when set,
   use keyring login for all `gh` calls this session.
2. If no active user and `GH_TOKEN` or `GITHUB_TOKEN` is set → validate with
   `gh api user`.
3. Valid → use env token auth for all `gh` calls this session.
4. Invalid → unset both vars, halt with `blocked`; suggest `gh auth login` or a
   valid token for CI.
5. No active user and no env token → halt with `blocked`; suggest `gh auth login`
   or export `GH_TOKEN` for automation.

## GitHub PR Detection

### Resolve owner/repo explicitly

Do this first, before any `gh api` call. `gh` expands `{owner}`/`{repo}` from the
*current directory's* default remote — which silently resolves to the wrong repo
(or none) when the reviewer runs from a different clone, a fork, or a directory
with multiple/renamed remotes. That is a common cause of "it didn't fetch the
comments": the API call succeeds against the wrong repo and returns an empty set.

Resolve the canonical base repo (where the PR and its comments live) from the PR
reference itself, not from the working directory:

```bash
# PR_REF = full PR URL, #123, 123, or "current"
if printf '%s' "$PR_REF" | grep -qE '^https://github.com/[^/]+/[^/]+/pull/[0-9]+'; then
  SLUG="$(printf '%s' "$PR_REF" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/[0-9]+.*#\1#')"
  PR_NUMBER="$(printf '%s' "$PR_REF" | sed -E 's#.*/pull/([0-9]+).*#\1#')"
else
  # #123 / 123 / current → resolve slug from the local repo's default remote
  SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner)" || { echo "cannot resolve repo"; exit 1; }
  PR_NUMBER="$(printf '%s' "$PR_REF" | tr -d '#')"   # "current" handled by detection below
fi
OWNER="${SLUG%%/*}"; REPO="${SLUG##*/}"
echo "repo: $OWNER/$REPO  pr: ${PR_NUMBER:-<current-branch>}"
```

Use `$OWNER/$REPO` for every command below: substitute it for the literal
`{owner}/{repo}` placeholders in all `gh api repos/{owner}/{repo}/...` calls, and
pass `--repo "$OWNER/$REPO"` to every `gh pr ...` invocation. Never rely on
`gh`'s implicit current-directory repo resolution.

If PR number is omitted (detect from current branch — only valid when the local
checkout *is* the PR branch):

```bash
gh pr view --repo "$OWNER/$REPO" --json number,url,title,headRefName,baseRefName,headRefOid,isDraft,mergeStateStatus
```

If PR number is provided:

```bash
gh pr view <PR_NUMBER> --json number,url,title,body,state,isDraft,author,headRefName,baseRefName,headRefOid,mergeStateStatus,reviewDecision,statusCheckRollup
```

Confirm branch scope:

```bash
git branch --show-current
gh pr view <PR_NUMBER> --json headRefName,baseRefName -q '{head: .headRefName, base: .baseRefName}'
```

Never operate directly on the base branch.

Once the PR number is resolved, run the Phase 2 PR-context gate (see Preflight)
before collecting evidence or editing. Halt on failure.

## Evidence Collection

Collect read-only signals first. Filter server-side so only review signal
enters context — excluded data (generated files, passing-check logs, fat comment
objects) is never a review target, so trimming it costs no coverage:

```bash
# Diff — exclude generated/vendored paths. These are not human-authored and are
# never the review target; including them is pure noise. Adjust the globs per repo.
gh pr diff <PR_NUMBER> --repo "$OWNER/$REPO" \
  -- ':(exclude)*.lock' ':(exclude)**/dist/**' ':(exclude)**/*.min.js' \
     ':(exclude)**/__snapshots__/**' ':(exclude)**/vendor/**'

# Check status only (names + conclusions):
gh pr checks <PR_NUMBER> --repo "$OWNER/$REPO" --watch=false

# CI logs ONLY for failing checks — a passing check's log is never reviewed.
# List failures, then fetch logs for just those (e.g. gh run view <run-id> --log-failed):
gh pr checks <PR_NUMBER> --repo "$OWNER/$REPO" --watch=false \
  --json name,state,link -q '.[] | select(.state=="FAILURE")'

# Inline review comments — key fields only. Drop diff_hunk/urls/reactions and
# other fat fields that the classifier never reads:
gh api repos/$OWNER/$REPO/pulls/<PR_NUMBER>/comments --paginate \
  -q '.[] | {id, path, line, user: .user.login, body}'

# Issue (general) comments — key fields only:
gh api repos/$OWNER/$REPO/issues/<PR_NUMBER>/comments --paginate \
  -q '.[] | {user: .user.login, body}'

# One PR snapshot — each field requested once. Omits `comments` (fetched above)
# to avoid pulling the same threads twice:
gh pr view <PR_NUMBER> --repo "$OWNER/$REPO" \
  --json number,url,title,body,state,isDraft,author,reviews,files,commits,headRefOid,reviewDecision,statusCheckRollup
```

These filters drop only data the review never acts on — same findings, less
context. Do not use them to skip files a human would review (e.g. a hand-edited
config that happens to match a glob); widen or drop a glob when in doubt.

For resolved-thread state (to skip already-resolved threads), use the GraphQL
`reviewThreads` query in "Replying to Review Comments" — REST comments do not
carry resolution state.

If the comment calls return empty, confirm `$OWNER/$REPO` matches the PR URL
before concluding there are no comments — an empty result against the wrong repo
is indistinguishable from a genuinely uncommented PR.

Build this mental model:

- PR title/body and acceptance criteria.
- Changed files and diff size.
- CI/check status.
- Inline review comments.
- General issue comments.
- Bot vs human comments.
- Required approvals or changes requested.
- Latest reviewed commit vs current head commit.

Read local context before fixing:

- relevant changed files
- adjacent code
- existing tests
- project instructions: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, README, test docs
- dependency/config files needed to discover verification commands

## Classification Taxonomy

Classify every finding as one of these.

### Actionable

Needs a code, test, documentation, or config change now.

Examples:

- failing CI
- required review change
- bug in changed code
- missing test for changed behavior
- security weakness
- broken build/typecheck/lint
- PR description missing required testing/risk notes

### Informational

No immediate change required.

Examples:

- FYI comments
- duplicated bot comments
- optional style suggestions
- low-confidence suggestions
- comments outside PR scope

### Already addressed

Appears fixed by later commits.

Verification required:

- inspect current file content
- inspect current diff
- run relevant test/check if possible
- confirm the comment applies to old code, not current head

### Needs user decision

Stop and ask the user if a finding involves:

- product behavior ambiguity
- public API contract
- database migration risk
- authentication/authorization design
- payment/billing behavior
- secrets or production config
- CI/workflow weakening
- file deletion
- dependency removal
- broad refactor beyond PR scope

## Severity Model

Use this priority order:

- P0 critical: security exploit, data loss, crash, auth bypass, secret leak.
- P1 high: incorrect behavior, failing required check, broken edge case, review-blocking issue.
- P2 medium: maintainability, missing targeted test, confusing behavior, non-blocking quality issue.
- P3 low/info: polish, optional style, context note.

Security findings are blocking until fixed, disproven with evidence, or explicitly accepted by the user.

## Confidence Score

After classifying findings each iteration, assign one PR-level merge-readiness
score from `0` to `5`. This is Diffwarden's own judgment computed from collected
evidence — never a value self-reported by an external tool or agent. Recompute
it from current evidence on every iteration.

The score is always relative to the exact commit it was computed against. Two
runs at different head SHAs (or with checks in different states) can legitimately
produce different scores for the same PR — this is not a contradiction. Always
stamp the score with the head SHA and check-state it was measured at (see Final
Report). Never compare a score across runs without comparing their stamps first;
a stale-head review and a current-head review measure different code.

- `5/5` merge-ready: required checks pass (terminal success), no actionable
  findings, no open P0/P1/security issue, description has adequate
  summary/testing/risk notes.
- `4/5` minor polish: only P3 or informational findings remain.
- `3/5` implementation issues: one or more open P2 findings, a missing targeted
  test for changed behavior, or required checks still pending/in-progress with no
  other blocking finding (see pending rule below).
- `2/5` significant bugs: any open P1 finding or any failing required check.
- `0-1/5` critical problems: any open P0 or unresolved security finding, data
  loss/auth-bypass risk, or hard build/check failure.

Pending checks are not failing checks. A required check in a non-terminal state
(`pending`, `in_progress`, `queued`, `expected`) is unresolved evidence, not a
failure. Do not score it as a failing check (`2/5`) and do not score it as
passing (`5/5`). When the only thing holding the PR back is non-terminal checks,
cap the score at `3/5` and report `checks: pending` explicitly. Re-collect once
checks reach a terminal state before assigning a final score (see Loop step 15).

Safety caps override the scale. Regardless of other passing signals:

- Any unresolved P0 or security finding caps the score at `1/5`.
- Any failing (terminal-failure) required check caps the score at `2/5`.
- Any required check in a non-terminal state caps the score at `3/5` until it
  resolves; never declare `5/5` while a required check is still pending.
- A "needs user decision" finding caps the score at `3/5` until the user
  decides.

The score is advisory for ranking and reporting and a gate for the loop. It
never lowers a safety bar — a high score does not authorize merge, push, or
comment resolution, and Diffwarden still never auto-merges.

## Fix Planning Protocol

Before edits, produce a compact fix plan:

```text
Findings:
1. [ACTIONABLE][P1/security] file:line — issue
   Evidence: ...
   Fix: ...
   Verify: ...

Will change:
- path/to/file.ext
- tests/path/to/test.ext

Will run:
- exact test/lint commands

Will not change:
- unrelated files
- public API unless approved

Planned comment replies (if --reply-comments):
- comment-id / path:line — [type] draft reply
```

Rules:

- Fix root causes, not symptoms.
- Prefer smallest safe patch.
- Preserve existing project style.
- Add/adjust tests when behavior changes.
- Do not weaken tests, lints, branch protection, or CI workflows to pass checks.
- If diff grows beyond about 500 lines, stop and ask unless the user requested a large fix.

## Applying Fixes

Before editing:

```bash
git status --short
git diff --stat
```

After editing:

```bash
git diff --stat
git diff --check
```

Never run:

```bash
git reset --hard
git clean -fd
git push --force
git rebase
```

Unless the user explicitly approves after seeing risk.

Commit/push policy:

- Default: do not commit/push unless requested.
- If user requested full PR preparation, commits are allowed after verification.
- Never auto-merge.
- Never force-push.
- Before any commit, inspect staged diff.
- Before any push, verify current head did not change unexpectedly.

## Verification Strategy

Discover commands from:

- `package.json`
- `pyproject.toml`
- `pytest.ini`
- `tox.ini`
- `Makefile`
- `.github/workflows/*`
- README/docs
- project `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, or equivalent agent instruction files

Prefer targeted checks first:

- test file related to changed file
- linter for changed language
- typecheck for touched package
- security test for auth/input/data changes

Then run broader checks when cheap or required.

Examples:

```bash
npm test -- --runInBand path/to/test
npm run lint
npm run typecheck
pytest tests/path/test_file.py -q
ruff check path/to/file.py
cargo test -p package_name
make test
```

Verification report must include:

- command
- exit code
- pass/fail
- important output excerpt

If verification fails:

1. Diagnose root cause.
2. Do not hide or bypass failure.
3. Fix if scoped and safe.
4. Otherwise stop with blocker report.

## Loop Algorithm

Default max iterations: `3`.

For each iteration:

1. Run the Phase 1 preflight gate. If it fails, halt with a `blocked` report; do not continue.
2. Detect PR and current head SHA, then run the Phase 2 PR-context gate. Halt on failure.
3. Collect PR evidence.
4. Classify findings and compute the confidence score.
5. Stop if confidence is `5/5` (no actionable findings and required checks pass).
6. Produce fix plan.
7. Apply safe scoped fixes.
8. Run targeted verification.
9. Run broader verification if needed.
10. Inspect diff.
11. If commit/push authorized, commit/push.
12. If `--reply-comments` and posting authorized, reply on addressed inline review threads (see Replying to Review Comments). If `--resolve-replied` also authorized, resolve eligible threads.
13. If `--post-review` and posting authorized, post a `COMMENT` review with findings.
14. Re-collect PR evidence after checks complete or when user asks to stop.
15. If checks are still pending/in progress, report that state explicitly; do not claim merge-ready until required checks reach terminal passing state.

Stop immediately when:

- max iterations reached
- same finding reappears without progress
- verification fails for ambiguous root cause
- user decision is needed
- risk exceeds requested scope
- worktree contains unexpected unrelated changes
- PR head changes externally mid-loop
- PR is closed or merged externally

Success state (confidence `5/5`):

- required checks pass
- no actionable unresolved comments (each has a reply or is classified already-addressed with evidence)
- no known P0/P1/security issue
- PR description has adequate summary/testing/risk notes
- changed files are scoped and verified

Do not declare merge-ready below `5/5`. Report the current score and the
findings holding it down instead.

## Replying to Review Comments

Use when addressing review feedback on a PR you own or are preparing for merge.
This is distinct from `--post-review` (posting a new review as an external
reviewer). Thread replies acknowledge existing reviewer comments after fixes.

### Gate

Post replies only when both are true:

- `--reply-comments` was passed, and
- the user explicitly authorized posting for this run.

Otherwise report planned replies locally only (default).

Resolve threads only when all are true:

- `--reply-comments` and `--resolve-replied` were passed,
- the user explicitly authorized resolve for this run, and
- the thread received a `fixed` or `already-addressed` reply in this run.

### Reply taxonomy

Assign one type per inline review comment (or thread). Use in reply body prefix.

| Type | When | Resolve thread? |
|------|------|-----------------|
| `fixed` | Code changed this run; comment addressed | Yes, if `--resolve-replied` authorized |
| `already-addressed` | Fixed in an earlier commit on current head; verify against code | Yes, if `--resolve-replied` authorized |
| `defer` | Valid but out of scope for this PR; track for follow-up | No |
| `wontfix` | Disagree or not applicable; explain why | No |
| `needs-user` | Ambiguous product/API/risk decision; question for reviewer | No |

Map from classification:

- actionable + fixed now → `fixed`
- already addressed (verified on head) → `already-addressed`
- informational / optional → skip reply, or `defer` if acknowledgment helps
- needs user decision → `needs-user` (stop loop; do not resolve)
- out of PR scope → `defer` or `wontfix`

### Reply body templates

Prefix every posted reply so it is clearly automated:

```text
Diffwarden (automated reply — [TYPE])

[fixed] Fixed in {short_sha}. {one-line summary}. Verify: `{command}`
[already-addressed] Addressed in {short_sha}. {evidence: file:line or test}.
[defer] Deferred — {reason}. Follow-up: {issue/link or "none"}.
[wontfix] {reason}.
[needs-user] {question for reviewer}.
```

Redact secrets/tokens before posting.

### Workflow

After fixes are verified and commit SHA is known (push if authorized):

1. List inline review comments and threads:

   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --paginate
   ```

2. For GraphQL thread IDs (needed to resolve):

   ```bash
   gh api graphql -f query='
   query($owner: String!, $repo: String!, $pr: Int!) {
     repository(owner: $owner, name: $repo) {
       pullRequest(number: $pr) {
         reviewThreads(first: 100) {
           nodes {
             id
             isResolved
             path
             line
             comments(first: 1) { nodes { id body author { login } } }
           }
         }
       }
     }
   }' -f owner=OWNER -f repo=REPO -F pr=<PR_NUMBER>
   ```

3. Match each unaddressed human/bot inline comment to a finding and reply type.
4. Idempotency: skip if a prior Diffwarden reply exists on the same thread with
   the same type and commit SHA.
5. Post threaded reply (REST — use the **root** comment id of the thread):

   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments/{COMMENT_ID}/replies \
     -f body='Diffwarden (automated reply — fixed)

   Fixed in abc1234. Added null check before dereference. Verify: `pytest tests/foo.py -q`'
   ```

6. If `--resolve-replied` authorized and type is `fixed` or `already-addressed`:

   ```bash
   gh api graphql -f query='
   mutation($threadId: ID!) {
     resolveReviewThread(input: {threadId: $threadId}) {
       thread { isResolved }
     }
   }' -f threadId=THREAD_ID
   ```

7. Record coverage: replied N/M, resolved R/M, skipped (with reason).

Hard rules:

- Reply on existing threads only — do not use `--post-review` for this.
- Never resolve threads with `defer`, `wontfix`, or `needs-user` replies.
- Never resolve human threads unless `--resolve-replied` and explicit user authorization.
- Bot threads: may resolve with `--resolve-replied` when reply type is `fixed` or
  `already-addressed` and evidence is cited.
- If PR head changed since evidence collection, re-collect before posting.
- Do not edit or delete existing human comments.

## Comment Resolution Rules

Default: report, do not resolve. Use Replying to Review Comments when the user
wants thread replies; use resolve only via `--resolve-replied`.

Bot comments:

- May resolve only if user requested `--resolve-replied` and evidence proves the fix.
- Include evidence in reply: commit, file, line, test command.

Human comments:

- Do not resolve by default.
- Reply with `--reply-comments` when authorized; resolve only with
  `--resolve-replied` and explicit user authorization when fix is verified.

Stale comments:

- Treat as already addressed only after checking current code and latest commit.
- Reply with `already-addressed` and evidence; do not ignore because they are old.

Unreplyable comments:

- General issue comments (not inline) → note in final report; no thread reply API.
- Outdated diff lines → reply on thread root if thread still open; cite current fix location.

## Posting Review to PR

Use this when reviewing another developer's PR and the user wants findings
posted on GitHub instead of only reported locally. This is the primary mode for
acting as a reviewer on PRs you do not own.

Gate. Post only when both are true:

- `--post-review` was passed, and
- the user explicitly authorized posting for this run.

Otherwise report locally only (default).

Hard rules:

- Only post reviews of type `COMMENT`. Never `APPROVE`. Never `REQUEST_CHANGES`.
  Approval and change-request are human merge-gating decisions and are out of scope.
- Never resolve, dismiss, or edit existing human review threads **when using
  `--post-review`** (external reviewer mode). Thread replies and resolve under
  `--reply-comments` / `--resolve-replied` follow Replying to Review Comments.
- Never merge, push to the head branch, or modify the PR's commits when posting a review.
- Redact secrets/tokens from comment bodies before posting.
- Use the head SHA captured during evidence collection. If the PR head changed
  since, stop and re-collect; do not post against a stale commit.
- Prefix the review body so it is clearly an automated review, e.g.
  `Diffwarden review (automated — comment only, no approval)`.

Idempotency:

- Before posting, list existing PR review comments and check for prior
  Diffwarden comments at the same path/line.
- Do not repost duplicates. Skip resolved points; only add new or changed findings.

Read author and head before posting:

```bash
gh pr view <PR_NUMBER> --json author,headRefOid,isDraft,state
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --paginate
```

Post a summary review (comment-only):

```bash
gh pr review <PR_NUMBER> --comment --body-file diffwarden-review.md
```

Post a review with inline line comments in one call (event must be `COMMENT`):

```bash
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/reviews \
  -f event='COMMENT' \
  -f body='Diffwarden review (automated — comment only, no approval). Summary: ...' \
  -f 'comments[][path]=path/to/file.ext' \
  -F 'comments[][line]=NN' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=[P1/security] issue. Evidence: ... Suggested fix: ...'
```

Each posted finding should carry: severity tag, evidence, and a suggested fix —
the same content as the local report. Posting is advisory; it does not change
the PR's merge state.

## Security-Focused Checklist

When `--security-focus` or security-sensitive files are touched, check:

- authn/authz bypass
- missing ownership checks
- injection: SQL/NoSQL/command/template
- SSRF and unsafe URL fetches
- path traversal and unsafe file access
- unsafe deserialization
- XSS and output encoding
- CSRF/session/cookie weakness
- secret logging or token exposure
- cryptography misuse
- race conditions and TOCTOU
- data deletion or migration risk
- PII leakage

Security output must include:

- claim
- evidence
- exploitability or impact
- recommended fix
- verification command or review step

## Branch and CI Protection Guards

Never weaken quality gates to make Diffwarden pass.

Escalate before editing:

- `.github/workflows/**`
- branch protection configuration
- test snapshots that hide behavior changes
- linter/typecheck configuration
- auth, payments, migrations, secrets, infra config

Optional branch protection check:

```bash
gh api repos/{owner}/{repo}/branches/<BRANCH>/protection || true
```

If branch is protected, do not attempt direct push unless normal project workflow allows it.

## Dry Run Mode

In dry-run mode:

- collect PR evidence
- classify findings
- produce fix plan
- list verification commands
- list planned comment replies (if --reply-comments) without posting
- do not edit files
- do not commit
- do not push
- do not post thread replies or resolve comments

Use dry-run when risk is unclear or user asks for assessment only.

## Final Report Format

Reply compactly. Always print the Diffwarden version (the `version:` value from
this skill's frontmatter) on the first line so the user knows which playbook ran:

```text
Diffwarden vX.Y.Z result.

Status: merge-ready | needs fixes | blocked | user decision needed
Confidence: N/5 @ <head-sha> (checks: passing | pending | failing) — one-line reason
PR: <url>
Iterations: N/M

Findings:
- Fixed: N
- Remaining actionable: N
- Informational: N
- Already addressed: N

Comment replies:
- Replied: N/M (fixed: N, already-addressed: N, defer: N, wontfix: N, needs-user: N)
- Resolved threads: R (only if --resolve-replied authorized)
- Skipped: N — reason

Verification:
- PASS `command`
- FAIL `command` — reason

Changed files:
- path

Risks:
- risk or "none known"

Next action:
- merge / review diff / approve decision / run command
```

## Common Pitfalls

1. **Trusting bot comments without checking current code.** Always verify against current head.
2. **Fixing CI by weakening CI.** Never reduce test/lint/security coverage to pass.
3. **Resolving human comments too aggressively.** Human review is a decision trail; preserve it unless `--resolve-replied` is authorized and reply type is `fixed` or `already-addressed`.
4. **Replying without evidence.** Every `fixed` reply must cite commit SHA and verification command.
5. **Overbuilding beyond PR scope.** Diffwarden is a guardian, not a refactor engine.
6. **Skipping tests because fix is small.** Run at least a targeted verification when behavior changes.
7. **Ignoring dirty worktree.** Protect uncommitted user work first.
8. **Letting loops oscillate.** If the same issue returns, stop and report root cause.
9. **Believing external agents.** Read files and run commands before declaring success.
10. **Empty comment fetch = no comments.** A `gh api` call against the wrong repo (implicit cwd resolution, fork, renamed remote) returns an empty set that looks identical to a genuinely uncommented PR. Resolve `OWNER/REPO` from the PR reference and confirm it before trusting an empty result.
11. **Halting a review because the PR branch is not checked out.** Reviewing another developer's PR does not require a local checkout. Use review-only mode: pin the PR head SHA and read evidence via the API; do not fail the head-drift gate.

## Verification Checklist

Before final answer:

- [ ] If invoked via `/diffwarden` or `/dw`, command parsed and expanded to skill flags before the loop.
- [ ] GitHub auth resolved: gh user login preferred (env tokens unset when user active); else valid env token; no token search.
- [ ] Phase 1 preflight gate passed (env); halted on failure.
- [ ] `OWNER/REPO` resolved from the PR reference (not implicit cwd repo); substituted into all `gh api`/`gh pr` calls.
- [ ] Phase 2 PR-context gate passed; halted on failure. Local-edit mode checked base/head drift; review-only mode pinned PR head SHA and skipped local checkout checks.
- [ ] PR detected and URL reported.
- [ ] Local-edit mode only: current branch is PR head, not base branch. (Review-only mode skips this.)
- [ ] Worktree state inspected (local-edit mode only).
- [ ] Checks/comments/diff collected; empty comment results confirmed against the correct repo, not assumed absent.
- [ ] Findings classified and confidence score computed from evidence, stamped with head SHA and check-state.
- [ ] Merge-ready declared only at confidence `5/5`; never `5/5` while required checks are pending.
- [ ] Fix plan made before edits.
- [ ] Risk gates respected.
- [ ] Tests/lints/typechecks run where applicable.
- [ ] No force-push, auto-merge, or history rewrite.
- [ ] No human comment resolved without explicit approval and `--resolve-replied`.
- [ ] If thread replies were posted, each cites type, evidence, and commit SHA where applicable.
- [ ] If a review was posted, it was `COMMENT` only (no approve/request-changes) and authorized.
- [ ] Final report includes status, findings, verification, changed files, risks, next action.
