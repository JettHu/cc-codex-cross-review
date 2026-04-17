---
name: review-plan-codex
description: Prepare a review tracking file and delegate plan review to Codex for critical independent assessment
metadata:
  author: JettHu
  version: "0.1.0"
disable-model-invocation: true
argument-hint: "[--wait|--background] <plan-file-path>"
allowed-tools: Read Bash(${CLAUDE_SKILL_DIR}/*) AskUserQuestion
---

## Review Plan with Codex

### Step 1: Parse arguments

Extract optional flags (`--wait`, `--background`) and the plan file path from `$ARGUMENTS`.

### Step 2: Choose execution mode

- If `--wait` is present, run in foreground.
- If `--background` is present, run in background.
- Otherwise, use `AskUserQuestion` once with two options:
  - `Wait for results`
  - `Run in background (Recommended)`

### Step 3: Run review

Everything — file validation, review file creation, prompt rendering, round counting, session reuse, Codex invocation, and fallback — is handled by a single script:

**Foreground**:
```bash
${CLAUDE_SKILL_DIR}/run-review.sh <plan-file-path>
```

**Background**:
```typescript
Bash({
  command: `${CLAUDE_SKILL_DIR}/run-review.sh <plan-file-path>`,
  description: "Codex plan review",
  run_in_background: true
})
```

The script outputs `--- REVIEW_METADATA ---` followed by a JSON line at the end. Parse it to get `review_file`, `round`, `codex_status`, etc.

### Step 4: Report results

**If foreground + Codex ran successfully** (`codex_status: "ok"`):
Read the review file and show the user:
- The overall rating
- The consensus status
- Top 3 critical issues (if any)
- The review file path

**If background**: tell the user to check `/codex:status` for progress.

**If fallback** (`codex_status: "fallback"`): the script already printed the prompt. Tell the user they can copy it to Codex manually, and that the prompt is also saved at the temp file path shown in metadata.
