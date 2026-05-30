---
name: diffwarden
description: "Use when preparing a pull request for merge: inspect diffs, collect checks and review comments, classify findings, fix safe issues, verify, and loop until merge-ready."
version: 0.1.1
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

Run before any edits:

```bash
git rev-parse --show-toplevel
git status --short
git branch --show-current
git remote -v
command -v gh || true
gh auth status
```

Stop if:

- not inside a git repo
- GitHub CLI is unavailable or unauthenticated
- no PR can be detected and no PR number was provided
- current branch is `main`, `master`, `trunk`, or the PR base branch
- worktree has unrelated dirty files that may be overwritten
- PR is closed or merged
- a human pushed new commits mid-loop and state is stale

Dirty worktree rule:

- If dirty files are unrelated to the PR fix, stop and ask.
- If dirty files are expected current-task edits, record them before continuing.

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

1. Run preflight.
2. Detect PR and current head SHA.
3. Collect PR evidence.
4. Classify findings.
5. Stop if no actionable findings and required checks pass.
6. Produce fix plan.
7. Apply safe scoped fixes.
8. Run targeted verification.
9. Run broader verification if needed.
10. Inspect diff.
11. If commit/push authorized, commit/push.
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

Success state:

- required checks pass
- no actionable unresolved comments
- no known P0/P1/security issue
- PR description has adequate summary/testing/risk notes
- changed files are scoped and verified

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

- [ ] PR detected and URL reported.
- [ ] Current branch is PR head, not base branch.
- [ ] Worktree state inspected.
- [ ] Checks/comments/diff collected.
- [ ] Findings classified.
- [ ] Fix plan made before edits.
- [ ] Risk gates respected.
- [ ] Tests/lints/typechecks run where applicable.
- [ ] No force-push, auto-merge, or history rewrite.
- [ ] No human comment resolved without explicit approval.
- [ ] Final report includes status, findings, verification, changed files, risks, next action.
