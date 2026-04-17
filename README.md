# x-review

Cross-model plan review plugin for Claude Code. The "x" stands for cross — Claude Code orchestrates, Codex reviews critically, forming an adversarial feedback loop.

## What it does

Two slash commands for a multi-round plan review workflow:

- **`/x-review:review-plan-codex [--wait|--background] <plan-file>`** — Prepares a review tracking file, renders a structured review prompt, and delegates to Codex for critical independent assessment. Supports multi-round reviews with Codex session reuse.
- **`/x-review:apply-review-codex <plan-file>`** — Reads the latest Codex review, evaluates each issue, accepts or rejects with reasons, and applies accepted suggestions to the plan.

## Workflow

```
/x-review:review-plan-codex docs/planning/my-plan.md    # Round 1: Codex reviews
/x-review:apply-review-codex docs/planning/my-plan.md   # Claude applies feedback
/x-review:review-plan-codex docs/planning/my-plan.md    # Round 2: Codex re-reviews (reuses session)
/x-review:apply-review-codex docs/planning/my-plan.md   # Claude applies again
...                                                      # Repeat until APPROVED
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
# Add the marketplace
claude plugins marketplace add JettHu/jetthu-cc-plugins

# Install the plugin
claude plugins install x-review
```

Or test locally during development:

```bash
claude --plugin-dir ./path/to/cc-codex-cross-review
```

## Options

### /x-review:review-plan-codex

```
/x-review:review-plan-codex [--wait|--background] <plan-file-path>
```

- `--wait` — Run review in foreground (default: asks)
- `--background` — Run review in background, check `/codex:status` for progress

### /x-review:apply-review-codex

```
/x-review:apply-review-codex <plan-file-path>
```

## How it works

1. **`run-review.sh`** handles all mechanical work: file validation, review file creation, round counting, previous issue summary extraction, prompt rendering with XML blocks (borrowing best practices from Codex's adversarial-review), and Codex invocation.
2. **Multi-round session reuse**: Round 2+ uses `--resume-last` to reuse the Codex thread, improving KV cache hit rate and reducing token cost.
3. **Decision persistence**: `apply-review-codex` writes accept/reject decisions back to the review file. In the next round, `run-review.sh` extracts these decisions and embeds them in the prompt — so Codex knows what was rejected and won't re-raise the same issues.
4. **Graceful fallback**: If Codex is not installed, the rendered prompt is output for manual copy-paste.
5. **Minimal Claude overhead**: Claude only chooses execution mode and reports results. All file operations and prompt rendering are handled by shell scripts.
