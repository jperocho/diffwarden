# Changelog

All notable changes to Diffwarden are documented here.

Format follows Keep a Changelog style. Version tags use SemVer.

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
