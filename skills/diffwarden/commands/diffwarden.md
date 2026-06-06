# Diffwarden

Read and follow the **diffwarden** skill (`SKILL.md`).

The user text after this command (if any) is a Diffwarden invocation. Parse per the skill **Slash Commands** section:

- No args → `help`
- Else parse subcommand, optional PR (`#123`, URL, `current`) **or** local target (`local`, `staged`, `worktree`) **or**, for `review-plan`, a `<filepath>`, and flags (`--comment`, `--reply`, `--resolve`, `--security`, `--delegate`, `--push`, `--max N`, `--dry-run`)

Examples: `review`, `review #123 --comment`, `fix --reply --resolve`, `status`, `review local`, `fix staged --security`, `review-plan docs/plan.md`.

If the `caveman` skill is loaded, run in caveman mode — see the skill **Caveman Mode** section.

Expand to skill flags, run full Diffwarden loop. Do not rephrase unless parse fails.
