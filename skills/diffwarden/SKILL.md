---
name: diffwarden
description: "Use when preparing a pull request for merge: inspect diffs, collect checks and review comments, classify findings, fix safe issues, verify, and loop until merge-ready."
version: 0.4.0
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
preflight -> detect PR -> collect evidence -> classify -> plan fixes -> apply safe fixes -> verify -> optional push -> re-check -> report
```

Default stance: conservative. Diffwarden prepares a PR for merge. It does not auto-merge.

## When to Use

Use Diffwarden when the user asks to:

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
- `--security-focus`, optional. Prioritize auth, input validation, secrets, data loss, SSRF, injection, path traversal, crypto, and logging leaks.
- `--max-iterations N`, optional. Default `3`; hard max `5` unless the user explicitly asks otherwise.

Initial platform:

- GitHub via `gh` CLI.

Future platforms:

- GitLab via `glab`.
- Perforce via `p4`.
- Greptile MCP adapter.

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
of every loop iteration. If any check below fails, **halt immediately**: do not
classify, plan, edit, commit, push, or post. Emit a `blocked` report naming the
failed check and the exact command output, then stop.

Run this gate script. It exits non-zero on any hard failure so the result is
machine-checkable, not a judgment call:

```bash
set -u
fail() { echo "PREFLIGHT FAIL: $*" >&2; exit 1; }

# In a git repo?
git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repo"

# GitHub CLI present and authenticated?
command -v gh >/dev/null 2>&1 || fail "gh CLI not installed"
gh auth status >/dev/null 2>&1 || fail "gh not authenticated"

# Remote configured?
git remote -v | grep -q . || fail "no git remote configured"

# Not on a protected/base branch?
BR="$(git branch --show-current)"
case "$BR" in
  main|master|trunk|develop) fail "on protected branch: $BR" ;;
esac

# Capture state for later staleness checks.
HEAD_SHA="$(git rev-parse HEAD)"
echo "preflight ok: branch=$BR head=$HEAD_SHA"
git status --short
```

After the script passes, still confirm these by inspecting its output — they are
not auto-failed because they need judgment or PR context:

- branch is not the PR base branch (compare `$BR` to the PR's `baseRefName`)
- a PR can be detected or a PR number was provided
- PR is not closed or merged
- PR head has not changed externally since the last iteration (compare
  `$HEAD_SHA` and the PR's `headRefOid`)
- worktree has no unrelated dirty files that may be overwritten

If any of these fail, halt with a `blocked` report exactly as for a script
failure.

Dirty worktree rule:

- If dirty files are unrelated to the PR fix, stop and ask.
- If dirty files are expected current-task edits, record them before continuing.

Never proceed past a failed gate by "fixing" the environment silently (e.g.
stashing user changes, switching branches, re-authenticating) without explicit
user approval.

## GitHub PR Detection

If PR number is omitted:

```bash
gh pr view --json number,url,title,headRefName,baseRefName,headRefOid,isDraft,mergeStateStatus
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

## Evidence Collection

Collect read-only signals first:

```bash
gh pr diff <PR_NUMBER>
gh pr checks <PR_NUMBER> --watch=false
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --paginate
gh api repos/{owner}/{repo}/issues/<PR_NUMBER>/comments --paginate
gh pr view <PR_NUMBER> --json number,url,title,body,state,isDraft,author,reviews,comments,files,commits,headRefOid,reviewDecision,statusCheckRollup
```

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

- `5/5` merge-ready: required checks pass, no actionable findings, no open
  P0/P1/security issue, description has adequate summary/testing/risk notes.
- `4/5` minor polish: only P3 or informational findings remain.
- `3/5` implementation issues: one or more open P2 findings, or a missing
  targeted test for changed behavior.
- `2/5` significant bugs: any open P1 finding or any failing required check.
- `0-1/5` critical problems: any open P0 or unresolved security finding, data
  loss/auth-bypass risk, or hard build/check failure.

Safety caps override the scale. Regardless of other passing signals:

- Any unresolved P0 or security finding caps the score at `1/5`.
- Any failing required check caps the score at `2/5`.
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

1. Run the preflight gate. If it fails, halt with a `blocked` report; do not continue.
2. Detect PR and current head SHA.
3. Collect PR evidence.
4. Classify findings and compute the confidence score.
5. Stop if confidence is `5/5` (no actionable findings and required checks pass).
6. Produce fix plan.
7. Apply safe scoped fixes.
8. Run targeted verification.
9. Run broader verification if needed.
10. Inspect diff.
11. If commit/push authorized, commit/push. If `--post-review` and posting authorized, post a `COMMENT` review with findings.
12. Re-collect PR evidence after checks complete or when user asks to stop.
13. If checks are still pending/in progress, report that state explicitly; do not claim merge-ready until required checks reach terminal passing state.

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
- no actionable unresolved comments
- no known P0/P1/security issue
- PR description has adequate summary/testing/risk notes
- changed files are scoped and verified

Do not declare merge-ready below `5/5`. Report the current score and the
findings holding it down instead.

## Comment Resolution Rules

Default: report, do not resolve.

Bot comments:

- May resolve only if user requested it and evidence proves the fix.
- Include evidence: commit, file, line, test command.

Human comments:

- Do not resolve by default.
- Only resolve if the user explicitly asks and the fix directly addresses the comment.

Stale comments:

- Treat as already addressed only after checking current code and latest commit.
- Do not ignore comments just because they are old.

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
- Never resolve, dismiss, or edit existing human review threads.
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
- do not edit files
- do not commit
- do not push
- do not resolve comments

Use dry-run when risk is unclear or user asks for assessment only.

## Final Report Format

Reply compactly:

```text
Diffwarden result.

Status: merge-ready | needs fixes | blocked | user decision needed
Confidence: N/5 — one-line reason
PR: <url>
Iterations: N/M

Findings:
- Fixed: N
- Remaining actionable: N
- Informational: N
- Already addressed: N

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
3. **Resolving human comments too aggressively.** Human review is a decision trail; preserve it unless asked.
4. **Overbuilding beyond PR scope.** Diffwarden is a guardian, not a refactor engine.
5. **Skipping tests because fix is small.** Run at least a targeted verification when behavior changes.
6. **Ignoring dirty worktree.** Protect uncommitted user work first.
7. **Letting loops oscillate.** If the same issue returns, stop and report root cause.
8. **Believing external agents.** Read files and run commands before declaring success.

## Verification Checklist

Before final answer:

- [ ] Preflight gate passed (script exit 0 + judgment checks); halted on failure.
- [ ] PR detected and URL reported.
- [ ] Current branch is PR head, not base branch.
- [ ] Worktree state inspected.
- [ ] Checks/comments/diff collected.
- [ ] Findings classified and confidence score computed from evidence.
- [ ] Merge-ready declared only at confidence `5/5`.
- [ ] Fix plan made before edits.
- [ ] Risk gates respected.
- [ ] Tests/lints/typechecks run where applicable.
- [ ] No force-push, auto-merge, or history rewrite.
- [ ] No human comment resolved without explicit approval.
- [ ] If a review was posted, it was `COMMENT` only (no approve/request-changes) and authorized.
- [ ] Final report includes status, findings, verification, changed files, risks, next action.
