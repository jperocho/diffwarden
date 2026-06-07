# Diffwarden (`/dw`)

Read and follow the **diffwarden** skill (`SKILL.md`).

The user text after this command (if any) is a Diffwarden invocation. Parse per the skill **Slash Commands** section:

- No args → `help`
- Else parse subcommand (`review`, `fix`, `prepare`, `security`, `status`, `help`), an optional target — a PR (`#123`, URL, `current`), a local target (`local`, `staged`, `worktree`), or a `.md` plan filepath — and flags (`--as-code`, `--as-plan`, `--comment`, `--reply`, `--resolve`, `--security`, `--delegate`, `--push`, `--max N`, `--dry-run`)
- `review`/`fix` auto-detect the target (code vs plan) per the skill **Target Auto-Detection** section; `--as-code`/`--as-plan` override. Print the resulting `detected: code review | plan review | code fix | plan fix` banner before working. `review-plan`/`fix-plan <filepath>` are hidden back-compat aliases for `review`/`fix <filepath> --as-plan` — accept them, but don't advertise them.

Examples: `review`, `review #123 --comment`, `fix --reply --resolve`, `status`, `review local`, `fix staged --security`, `review docs/plan.md`, `review docs/plan.md --as-code`, `fix docs/plan.md`.

If the `caveman` skill is loaded, run in caveman mode — see the skill **Caveman Mode** section.

Expand to skill flags, run full Diffwarden loop. Do not rephrase unless parse fails.
