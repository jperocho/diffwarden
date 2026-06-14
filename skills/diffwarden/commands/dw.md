# Diffwarden (`/dw`)

Read and follow the **diffwarden** skill (`SKILL.md`).

The user text after this command (if any) is a Diffwarden invocation. Parse per the skill **Slash Commands** section:

- No args → `help`
- Else parse subcommand (`review`, `loop`, `status`, `comment`, `help`), an optional target, and flags
- Primary subcommands: `review` (read-only), `loop` (review-fix-verify until c5/5), `status` (score only), `comment` (short PR review comment), `help`
- Compatibility aliases (accept, don't advertise): `fix` → `loop`; `prepare` → `loop --push`; `security` → `review --security`; `review-plan <file>` → `review <file> --as-plan`; `fix-plan <file>` → `loop <file> --as-plan`
- Targets: `workspace` (current folder, git not required), `local` (git working tree), `staged` (git staged), PR (`#123`, URL), or file path (plan/docs/guides/tutorials)
- Flags: `--mvp`, `--verbose`, `--orchestrate`, `--commit`, `--push`, `--as-code`, `--as-plan`, `--web` (alias `--research`), `--reply`, `--resolve`, `--delegate`, `--dry-run`, `--max N`, `--review-model`, `--fix-code-model`, `--fix-text-model`, `--security`
- `review`/`loop` auto-detect code vs document mode per skill **Target Auto-Detection**; `--as-code`/`--as-plan` override. `comment` is PR-only.
- `--web` is opt-in per-finding consent; valid on `review`/`loop` (code targets); rejected on `status` and document mode.
- `--orchestrate` enables optional reviewer/fixer role split; off by default. Model flags override config when set.
- Default output is lean (`cN/5` loop lines); `--verbose` restores full report.

Examples: `loop workspace`, `review #123`, `comment #123`, `status local`, `loop docs/install.md --as-plan`, `review --security`, `loop --orchestrate`, `loop --mvp`, `review #123 --web`.

If the `caveman` skill is loaded, run in caveman mode — see the skill **Caveman Mode** section.

Expand to skill flags, run full Diffwarden loop. Do not rephrase unless parse fails.
