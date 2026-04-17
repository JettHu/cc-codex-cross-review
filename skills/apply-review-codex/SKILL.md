---
name: apply-review-codex
description: Apply Codex review feedback — evaluate each issue and revise the plan accordingly
disable-model-invocation: true
argument-hint: "<plan-file-path>"
allowed-tools: Read Edit Bash(${CLAUDE_SKILL_DIR}/*)
---

## Apply Review Feedback to Plan

### Step 1: Extract latest round

Derive the review file path from `$ARGUMENTS`:
- Rule: `{plan-dir}/reviews/{plan-filename-without-.md}-review.md`

Run the prep script to get only the latest round (avoids reading the full review history):

```bash
"${CLAUDE_SKILL_DIR}/extract-latest-round.sh" "<review-file-path>"
```

Parse the output: the review round content is above `--- ROUND_METADATA ---`, and the metadata JSON is below it.

If the script fails (file not found, no rounds), report the error and stop.

### Step 2: Read the plan file

Read the plan file at `$ARGUMENTS`. If it does not exist, report the error and stop.

### Step 3: Evaluate and apply

Go through each issue **one by one** in the latest round. For each issue:

1. **Evaluate**: Is this a valid concern? Is the suggestion actionable and appropriate?
2. **Decide**: Accept or Reject.
3. **Act**:
   - If **accepted**: revise the relevant section of the plan file directly.
   - If **rejected**: no change to the plan.

Update the plan file directly — do not create a new file.

### Step 4: Write decisions to review file

Append the apply decisions table to the review file so that future Codex rounds can see what was accepted/rejected and why:

```md

### Apply Decisions (by Claude)
| # | Issue | Decision | Reason |
|---|-------|----------|--------|
| 1 | {title} | Accepted | — |
| 2 | {title} | Rejected | {brief reason} |
```

Use the Edit tool to append this table at the end of the review file (after the latest round's content).

### Step 5: Report summary

Output a summary table:

| # | Issue | Severity | Decision | Action Taken |
|---|-------|----------|----------|-------------|
| 1 | {title} | {severity} | Accepted / Rejected | {brief description of change or rejection reason} |

Then show:
- **Accepted**: {count} / {total}
- **Rejected**: {count} / {total}
- Key changes made to the plan

### Guidelines

- Be an independent thinker, not a rubber stamp. Reject suggestions that:
  - Introduce unnecessary complexity
  - Conflict with the project's existing architecture or conventions
  - Are based on incorrect assumptions about the codebase
  - Would change scope significantly without clear benefit
- Accept suggestions that identify genuine gaps, risks, or improvements
- When accepting, make the minimum change needed — do not over-revise
