# plan-review-codex

A Claude Code plugin that delegates plan document reviews to Codex and applies feedback iteratively.

## What it does

Two slash commands for a multi-round plan review workflow:

- **`/review-plan-codex <plan-file>`** — Prepares a review tracking file, renders a structured review prompt, and delegates to Codex for critical independent assessment. Supports multi-round reviews with Codex session reuse.
- **`/apply-review-codex <plan-file>`** — Reads the latest Codex review, evaluates each issue, and applies accepted suggestions to the plan.

## Workflow

```
/review-plan-codex docs/planning/my-plan.md    # Round 1: Codex reviews
/apply-review-codex docs/planning/my-plan.md   # Claude applies feedback
/review-plan-codex docs/planning/my-plan.md    # Round 2: Codex re-reviews (reuses session)
/apply-review-codex docs/planning/my-plan.md   # Claude applies again
...                                             # Repeat until APPROVED
```

Review files are stored in a `reviews/` subdirectory next to the plan:
```
docs/planning/my-plan.md
docs/planning/reviews/my-plan-review.md
```

Clean up after review: `rm -rf docs/planning/reviews/`

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Codex plugin](https://github.com/openai/codex-plugin-cc) (optional — falls back to manual prompt copy if not installed)

## Install

```bash
claude plugins add <repo-url>
```

## Options

### /review-plan-codex

```
/review-plan-codex [--wait|--background] <plan-file-path>
```

- `--wait` — Run review in foreground (default: asks)
- `--background` — Run review in background, check `/codex:status` for progress

### /apply-review-codex

```
/apply-review-codex <plan-file-path>
```

## How it works

1. `run-review.sh` handles all mechanical work: file validation, review file creation, round counting, prompt rendering with XML blocks (borrowing best practices from Codex's adversarial-review), and Codex invocation.
2. Multi-round reviews reuse the Codex session via `--resume-last`, improving KV cache hit rate and reducing token cost.
3. If Codex is not installed, the rendered prompt is output for manual copy-paste.
4. Claude's role is minimal: choose execution mode and report results.
