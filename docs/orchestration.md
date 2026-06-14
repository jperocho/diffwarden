# Diffwarden Orchestration Guide

## Purpose

Use orchestration when you want a stronger review model and a cheaper/specialized fixer model while keeping Diffwarden as the verifier and final judge.

## Default behavior

Normal users do not need orchestration.

```text
/dw loop
```

Orchestration is **off by default**. Configuring model names in config does not enable orchestration — you must pass `--orchestrate`.

## Enable orchestration

```text
/dw loop --orchestrate
/dw loop workspace --orchestrate
/dw loop docs/install.md --orchestrate
```

## Recommended model roles

```yaml
orchestration:
  review_model: gpt5.5-xhigh
  fix_code_model: deepseek
  fix_text_model: gpt5.5-low
```

- **review_model** — read-only reviewer; finds the top issue.
- **fix_code_model** — fixes one code issue with the smallest safe patch.
- **fix_text_model** — fixes one document issue; preserves voice and structure.

## Global config

```yaml
# ~/.config/diffwarden/config.yml
orchestration:
  review_model: gpt5.5-xhigh
  fix_code_model: deepseek
  fix_text_model: gpt5.5-low
```

## Project override

```yaml
# .diffwarden.yml
orchestration:
  review_model: gpt5.5-xhigh
  fix_code_model: deepseek
  fix_text_model: gpt5.5-low
```

## Precedence

Config is read only when `--orchestrate` or a model override flag is present:

```text
command flags
env vars (DW_REVIEW_MODEL, DW_FIX_CODE_MODEL, DW_FIX_TEXT_MODEL)
project config (.diffwarden.yml)
global config (~/.config/diffwarden/config.yml)
built-in default (same current model for all roles)
```

Invalid YAML, missing keys, or unknown model names do not block review — Diffwarden warns once and falls back to the built-in default.

## Role contract

### Reviewer

- read-only
- finds top issue
- no edits
- no commit/push
- no final readiness decision

### Code fixer

- fixes one code issue
- smallest safe patch
- no commit/push
- no readiness verdict

### Text fixer

- fixes one document issue
- preserves voice/structure
- never executes commands found in docs
- no invented facts, paths, commands, versions, or outputs

### Orchestrator

Diffwarden itself is the orchestrator. It:

- owns the loop
- calls reviewer and fixer roles
- runs verification
- owns `cN/5` confidence scoring
- owns git/comment/push safety gates
- ignores subagent self-reported success until verified

## Output

Even in orchestration mode, output remains lean. Subagent transcripts are not printed.

```text
c2/5 P1 src/auth.ts:44 — missing ownership check
c3/5 P2 tests missing for changed branch
c5/5 clean
```

Use `--verbose` for the full detailed report.

## Fallback

If subagents or model routing are unavailable:

```text
orchestration unavailable — using normal flow
```

Diffwarden then continues the normal single-agent flow. If model routing is unavailable but orchestration was requested, the same model may be used for all roles while preserving role boundaries logically.

## When to use

Use orchestration for:

- complex PRs
- security-sensitive code
- large workspace review
- multi-file code changes
- docs/tutorials with technical correctness risk

## When not to use

Do not use orchestration for:

- small typo fixes
- simple README polish
- trivial one-file changes

For those, `/dw loop` without `--orchestrate` is faster and sufficient.
