# x-review

Cross-model plan review skills for coding agents. The "x" stands for cross — your coding agent orchestrates, another model reviews critically, forming an adversarial feedback loop.

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

- A coding agent that supports skills (Claude Code, Cursor, OpenCode, etc.)
- [Codex plugin](https://github.com/openai/codex-plugin-cc) — recommended for full automation in Claude Code. Install it with:
  ```bash
  claude plugins marketplace add openai/codex-plugin-cc
  claude plugins install codex
  ```
  **Without Codex plugin**: the review prompt will be printed to terminal instead. You can manually copy it into [Codex CLI](https://github.com/openai/codex), ChatGPT, or any other LLM for review.

## Install

### Claude Code (recommended)

```bash
# Add the marketplace
claude plugins marketplace add JettHu/jetthu-cc-plugins

# Install the plugin
claude plugins install x-review
```

### Other agents

Install as a skill via [npx skills](https://github.com/vercel-labs/skills):

```bash
# Interactive — auto-detects your installed agents
npx skills add JettHu/cc-codex-cross-review

# Global install
npx skills add JettHu/cc-codex-cross-review -g

# Install to specific agents
npx skills add JettHu/cc-codex-cross-review -a cursor -a opencode
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
5. **Minimal agent overhead**: The orchestrating agent only chooses execution mode and reports results. All file operations and prompt rendering are handled by shell scripts.
