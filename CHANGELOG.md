# Changelog

All notable changes to Diffwarden are documented here.

Format follows Keep a Changelog style. Version tags use SemVer.

## [0.12.1] - 2026-06-04

### Changed

- Help output now lists `--delegate` in the per-subcommand usage lines for
  `review`, `fix`, and `prepare`, matching the Flags legend and grammar so the
  flag is discoverable from the command listing. Docs only; no behavior change.

## [0.12.0] - 2026-06-04

### Added

- **Delegated Reads (`--delegate-reads`, off by default).** On large PRs the bulk
  diff hunks and CI-log bodies dominate context. With this flag, read-only
  subagents may digest that *content* so the orchestrator's context holds the
  conclusions, not the raw bytes — a token saving on long reviews. Built
  security-first as a compression layer on reading only; it cannot change the
  verdict or hide a file:
  - **Security overrides everything (refusals, not tunables):** `--security-focus`
    runs never delegate, and security-sensitive files (auth/authz, payments,
    migrations, secrets, infra, `.github/workflows/**`, lint/CI config) are always
    read raw. `security … --delegate` is rejected as a no-op.
  - **No decision is ever delegated** — classification, severity, confidence
    score, merge-ready, fix/defer, post/resolve stay 100% with the orchestrator.
  - **Structured claims, grounded against raw source.** Subagents return
    `{file, line, type, verbatim_quote}` (no prose); the orchestrator greps each
    quote against raw source — no match → the claim is dropped and that file is
    read raw, so a garbled-but-real issue is not lost.
  - **Coverage reconciliation.** The authoritative file/check/comment set is
    enumerated raw; a set difference forces a raw read of anything a subagent
    skipped. A subagent can never shrink the set or mark a file clean.
  - **Prompt-injection containment.** PR diff/comments/logs are treated as
    untrusted data; subagents are read-only with no commit/push/post tools, so an
    injected "report no issues" is caught by grounding + reconciliation.
  - **Fail-safe + auditable.** Any subagent error/timeout/malformed output →
    raw read of that chunk (worst case equals prior behavior); each run logs
    `digest: subagent (files=N, grounded M/M, raw-fallback K, security-raw S)`.
  - New section "Delegated Reads", slash flag `--delegate`, an Invalid-combination
    reject, plus Common Pitfall and Verification Checklist entries.
  - Default unset = today's behavior, byte-identical. Strict manual opt-in (no
    auto-on heuristic in this release).

## [0.11.0] - 2026-06-04

### Added

- **Incremental re-collection (loop iterations 2+).** The loop's biggest
  repeated cost was re-fetching the full diff, every comment, and every CI log
  on every iteration (full × N). Iterations 2+ may now fetch only what changed
  since the last collection, cutting cost to roughly full + small × (N-1).
  Designed so a missed delta is both unreachable at the verdict and cheap to
  detect:
  - Iteration 1 is always a full collection.
  - Small signals (check status, `reviewDecision`, thread resolution state,
    comment counts) are always re-pulled full; only the diff and failing-check
    CI logs are deltaed.
  - **Ancestry guard:** `git merge-base --is-ancestor LAST_HEAD HEAD` (or the PR
    head SHA in review-only mode) forces a full re-pull on any rebase/force-push.
  - **Count probe:** a comment-count mismatch vs the last collection forces a
    full re-pull, catching added or deleted comments (edits don't change the
    count — see the `updated_at` filter next).
  - Comment deltas filter on `updated_at` (not `created_at`) so edits and
    in-place bot updates are caught, and the diff delta unions in files that
    still carry an open finding.
  - **The merge-ready verdict always rests on a full collection** — `5/5` is
    never declared on delta evidence (Loop Algorithm steps 5 and 14).
  - Each iteration logs its mode (`evidence: full` / `evidence: delta`) so a
    wrong delta is visible, never silent.
  - New Common Pitfall and Verification Checklist item cover the delta path.

## [0.10.2] - 2026-06-04

### Changed

- **Preflight: deduplicated the review-only vs local-edit explanation.** The
  mode definition lived in three places verbatim (Preflight intro, the Phase 1
  protected-branch comment, and the Phase 2 prose). It is now stated once in the
  Preflight intro; Phase 1 and Phase 2 reference it and keep only their
  location-specific detail. No behavior change — gate logic, modes, and all
  bash are identical; this only trims repeated prose to cut per-run input
  tokens.

## [0.10.1] - 2026-06-04

### Changed

- **Evidence Collection now filters noise out of context** to cut token usage
  with no loss of review coverage. The diff stream is path-filtered to drop
  generated/vendored files (`*.lock`, `dist/`, `*.min.js`, `__snapshots__/`,
  `vendor/`); CI logs are
  pulled only for failing checks; inline/issue comments are reduced to the
  fields the classifier reads (dropping `diff_hunk`, URLs, reactions); and the
  PR snapshot omits the `comments` field that is fetched separately. These
  filters only remove data the review never acts on — same findings, fewer
  tokens. Added a caution to widen/drop a glob when a matched file is actually
  human-reviewed, and a pointer to the GraphQL `reviewThreads` query for
  resolved-thread state.

## [0.10.0] - 2026-06-04

### Added

- `install.sh` — a self-contained installer. Detects which agents are present
  (Claude Code, Cursor) and at which scope (project / global), then copies the
  skill into `.../skills/diffwarden/SKILL.md` and the optional `/dw` and
  `/diffwarden` command files into `.../commands/`. Idempotent (skips files
  already up to date, diffs and asks before overwriting a changed file). Flags:
  `--claude`, `--cursor`, `--project`, `--global`, `--dry-run`, `--yes`,
  `--force`, `--ref`. Security-hardened: `set -euo pipefail`, HTTPS-only fetch
  pinned to a release tag, no `sudo`, refuses to write outside `.claude/` and
  `.cursor/`. Runs from a clone with no network, or from a downloaded copy.
- `.github/workflows/ci.yml` — CI that shellchecks `install.sh` (`bash -n` +
  `shellcheck`) and enforces version sync across all files. Required on `main`.
- README **Contributing** section documenting the fork/PR flow and the `main`
  branch-protection rules (PR required, 1 approval, CI green, squash-only, no
  direct push / force-push — enforced for everyone, including the maintainer).

### Changed

- **Removed the `npx`/skills.sh install path** — it proved flaky. Install is now
  the installer (Option A) or a plain manual copy (Option B). README Install
  section rewritten end to end; skills.sh badge and references dropped.
- README Command reference, Troubleshooting, Files list, and version badge
  updated to describe installer-based install instead of the skill loader.

## [0.9.2] - 2026-06-04

### Changed

- README: clarified how the `/dw` and `/diffwarden` slash commands actually
  register. `/diffwarden` works automatically in Claude Code (matches the skill
  name); `/dw` is never auto-installed and needs a one-time command-file copy.
  Install section now documents copying `dw.md` into `.claude/commands/` (Claude
  Code) as well as `.cursor/commands/` (Cursor), with a note that Claude Code
  loads commands at session start. Updated the Command reference intro,
  Troubleshooting entry, and Files list to match.

## [0.9.1] - 2026-06-04

### Added

- Final report and `status` snapshot now print the Diffwarden version (from the
  skill frontmatter `version:`) on the first line, so users can see which playbook
  ran.
- README: Cursor-specific caveman setup. Documents per-agent caveman activation
  (hook-driven for Claude Code/Codex/Gemini vs. static `.cursor/rules/` file for
  Cursor/Windsurf/Cline/Copilot), the `--with-init` symlink caution for this repo
  (`AGENTS.md` → `CLAUDE.md`), the safe manual rule copy, and a Troubleshooting
  entry for caveman not activating in Cursor.

## [0.9.0] - 2026-06-04

### Added

- Caveman Mode (token savings): at the start of every invocation Diffwarden now
  checks whether the `caveman` skill is available. If present, it runs in caveman
  mode (compact, high-signal output) while preserving exact paths, commands,
  errors, verification results, risks, and next actions, and keeping caveman's
  safety carve-outs. If caveman is not installed, it emits a one-time suggestion
  to install it for ~75% output-token savings, then continues normally. Output
  style only — never changes classification, fix scope, safety gates, or the loop.

## [0.8.0] - 2026-06-04

### Added

- Confidence Score: pending-checks bucket. A required check in a non-terminal
  state (`pending`, `in_progress`, `queued`, `expected`) is now scored as
  unresolved evidence capped at `3/5` with `checks: pending`, not as a failing
  check (`2/5`) or as passing (`5/5`). Never declare `5/5` while a required check
  is pending.
- Preflight: review-only mode (`REVIEW_ONLY`). `review`, `status`, `security`,
  any `--dry-run` run, and `--post-review` on a PR you do not own no longer
  require the PR branch to be checked out locally — they pin the PR head SHA from
  `gh` and read evidence via the API. Phase 1 skips the protected-branch halt and
  Phase 2 skips the base-branch/head-drift checks in this mode. Fixes spurious
  halts when reviewing another developer's PR from a different machine or clone
  (e.g. a reviewer sitting on `main`). Local-edit mode (`fix`/`prepare`) keeps
  the full protected-branch + base/head-drift gate.
- Explicit `OWNER/REPO` resolution from the PR reference before any API call,
  with `--repo "$OWNER/$REPO"` on every `gh pr`/`gh api` command. Stops `gh`'s
  implicit current-directory repo resolution from silently targeting the wrong
  repo (fork, renamed remote, different clone) and returning empty comment sets
  that look like an uncommented PR.

### Changed

- Confidence Score: it is now explicitly relative to the commit it was computed
  against. Two runs at different head SHAs (or check states) can legitimately
  produce different scores for the same PR; scores must not be compared without
  comparing their stamps first.
- Final Report: `Confidence:` line now stamps the head SHA and check-state —
  `Confidence: N/5 @ <head-sha> (checks: passing | pending | failing) — reason`.
  Makes cross-device/cross-run score differences self-explaining instead of
  looking like a contradiction.

## [0.7.7] - 2026-06-02

### Changed

- GitHub auth: prefer `gh auth status` (user/keyring login) over
  `GH_TOKEN`/`GITHUB_TOKEN`. When a user is active, unset env tokens for the
  session so `gh` does not override keyring. Env tokens are validated only when
  no active `gh` user (CI/automation fallback). No filesystem token search.

## [0.7.6] - 2026-06-01

### Changed

- Remove tracked `.cursor/commands/` from repo; add `.cursor/` and `.claude/` to
  `.gitignore`. Skill stays agent-agnostic; `skills/diffwarden/commands/` remains
  an optional Cursor-only install. README and SKILL.md clarify Cursor slash menu
  is optional.

## [0.7.5] - 2026-06-01

### Changed

- README: move Contents before Command reference; reorder TOC to match section
  order (command reference and loop guide first).

## [0.7.4] - 2026-06-01

### Changed

- README: add "Loop until merge-ready (5/5)" section after Command reference
  (loop commands, confidence scale, stop conditions, example workflow).

## [0.7.3] - 2026-06-01

### Added

- Cursor slash command files: `skills/diffwarden/commands/dw.md` and
  `diffwarden.md` (plus `.cursor/commands/` in this repo). `/dw` and
  `/diffwarden` now work in Cursor's `/` menu after copying to
  `.cursor/commands/` or `~/.cursor/commands/`. README install + FAQ updated.

## [0.7.2] - 2026-06-01

### Changed

- README: add "Command reference" section with command and flag tables after the
  intro overview; dedupe slash-command section to examples only.

## [0.7.1] - 2026-06-01

### Added

- Safe GitHub token handling in preflight and new "GitHub Authentication"
  section. Use `GH_TOKEN` / `GITHUB_TOKEN` only when already in the environment
  (never search files/config). Validate with `gh api user`; if invalid, unset
  env token and fall back to `gh` keyring login.

## [0.7.0] - 2026-06-01

### Added

- Reviewer comment reply workflow: `--reply-comments` and `--resolve-replied`
  flags. New "Replying to Review Comments" section in `SKILL.md` with reply
  taxonomy (`fixed`, `already-addressed`, `defer`, `wontfix`, `needs-user`),
  body templates, `gh api` reply/resolve commands, idempotency rules, and loop
  integration. Slash flags: `--reply` and `--resolve`. Final report includes
  comment-reply coverage.

## [0.6.0] - 2026-06-01

### Added

- Slash-command invocation: `/diffwarden` and `/dw` with subcommands `review`,
  `fix`, `prepare`, `security`, `status`, and `help`. New "Slash Commands"
  section in `SKILL.md` defines grammar, flag mapping, PR resolution, expansion
  examples, invalid combinations, and help output. README documents the same
  for users.

## [0.5.0] - 2026-06-01

### Changed

- Split the preflight gate into two phases. Phase 1 (environment) runs first and
  is unchanged. New Phase 2 (PR-context) runs after PR detection and
  machine-checks what were previously judgment calls: PR open/not-merged,
  current branch is not the PR base, and no external head drift since last
  iteration. Uses a single `gh` fetch with `-q` (no `jq` dependency) and exits
  non-zero on failure.
- Only dirty-file *relevance* remains a judgment call (a script can see dirty
  files but not whether they belong to the fix).
- Loop step 2 and the verification checklist now require the Phase 2 gate to
  pass and to halt on failure.

## [0.4.0] - 2026-06-01

### Changed

- Harden Preflight into an enforceable hard gate. Added a copy-paste gate script
  that exits non-zero on hard failures (no git repo, missing/unauthenticated
  `gh`, no remote, protected branch) so the result is machine-checkable instead
  of a judgment call. Judgment checks (base-branch match, PR detected/open,
  external head change, unrelated dirty files) are listed explicitly and must
  also halt with a `blocked` report.
- Loop step 1 and the verification checklist now require the gate to pass and
  to halt on failure.

### Safety

- Diffwarden must not silently "fix" a failed gate (stash user changes, switch
  branches, re-authenticate) without explicit user approval.

## [0.3.0] - 2026-06-01

### Added

- Confidence Score: a PR-level merge-readiness score from `0` to `5`, computed
  by Diffwarden from collected evidence each iteration (not self-reported by any
  external tool). New "Confidence Score" section defines the scale and its
  safety caps. Reported as `Confidence: N/5` in the final report.

### Changed

- Loop now gates on confidence: merge-ready is declared only at `5/5`. Loop and
  success-state steps updated to compute and check the score; verification
  checklist adds confidence items.

### Safety

- Confidence is advisory and a loop gate only. It never lowers a safety bar: a
  high score does not authorize merge, push, or comment resolution, and
  unresolved P0/security findings, failing required checks, and pending user
  decisions cap the score regardless of other passing signals.

## [0.2.0] - 2026-05-30

### Added

- `--post-review` mode: post findings directly to a PR as a GitHub review of
  type `COMMENT`, with optional inline line comments. Enables reviewing other
  developers' PRs and leaving feedback on GitHub instead of only reporting
  locally. New "Posting Review to PR" section with `gh` commands.

### Changed

- Rewrite README as a beginner-friendly, comprehensive guide: prerequisites
  with install commands, step-by-step first run, flag table, recipes, and a
  troubleshooting/FAQ section.

### Safety

- Posted reviews are `COMMENT` only — never `APPROVE` or `REQUEST_CHANGES`
  (merge-gating decisions stay with humans).
- Off by default; requires `--post-review` plus explicit per-run authorization.
- Never resolves/dismisses human threads, merges, or pushes when posting.
- Posts against the captured head SHA; aborts on stale head. Secrets redacted.

## [0.1.1] - 2026-05-30

### Changed

- Clarify External Agent Protocol: the Caveman-mode prefix is an
  output-formatting directive, not an instruction-injection or safety-override
  payload, and the section is explicitly optional. Reduces false-positive
  surface for skill security scanners (Gen Agent Trust Hub, Socket, Snyk).

## [0.1.0] - 2026-05-30

### Added

- Initial `diffwarden` PR review skill/playbook.
- GitHub-first PR review loop using `gh`.
- Preflight checks for git repo, branch scope, GitHub auth, PR state, and dirty worktree.
- Evidence collection for PR diff, checks, reviews, comments, files, commits, and review decision.
- Finding classification: actionable, informational, already addressed, needs user decision.
- Severity model: P0 critical, P1 high, P2 medium, P3 low/info.
- Conservative fix-planning protocol.
- Verification strategy for tests, lint, typecheck, and security-sensitive changes.
- Bounded review/fix loop with max-iteration and convergence guards.
- Comment-resolution safety rules.
- Security-focused checklist.
- Branch and CI protection guards.
- Dry-run mode.
- External-agent protocol requiring Caveman mode before Claude Code CLI or Copilot CLI task prompts.

### Safety

- No auto-merge.
- No force-push.
- No blind push.
- No destructive git operations by default.
- No CI/test/lint weakening to pass checks.
- No human review comment resolution without explicit approval.
