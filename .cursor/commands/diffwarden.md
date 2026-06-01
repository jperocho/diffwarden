# Diffwarden

Read and follow the **diffwarden** skill at `skills/diffwarden/SKILL.md`.

The user text after this command (if any) is a Diffwarden invocation. Parse per the skill **Slash Commands** section:

- No args → `help`
- Else parse subcommand, optional PR (`#123`, URL, `current`), and flags (`--comment`, `--reply`, `--resolve`, `--security`, `--push`, `--max N`, `--dry-run`)

Examples: `review`, `review #123 --comment`, `fix --reply --resolve`, `status`.

Expand to skill flags, run full Diffwarden loop. Do not rephrase unless parse fails.
