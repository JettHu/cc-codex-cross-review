#!/usr/bin/env bash
# run-review.sh — Prepare review file, render prompt, and delegate to Codex.
# All mechanical work in one script. Claude only needs to choose execution mode and report results.
#
# Usage:
#   run-review.sh [--model <model>] [--effort <level>] <plan-file-path>
#
# Output (JSON to stdout):
#   { "plan_title": "...", "review_file": "...", "round": N, "codex_status": "ok|fallback", ... }
#
# Exit codes:
#   0  — Codex executed successfully (or review file prepared for fallback)
#   1  — Plan file not found or other fatal error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse optional flags ---
CODEX_MODEL=""
CODEX_EFFORT=""

while [[ $# -gt 1 ]]; do
  case "$1" in
    --model)  CODEX_MODEL="$2"; shift 2 ;;
    --effort) CODEX_EFFORT="$2"; shift 2 ;;
    *) break ;;
  esac
done

PLAN_FILE="${1:?Usage: run-review.sh [--model <model>] [--effort <level>] <plan-file-path>}"

# --- Step 1: Validate plan file ---

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "ERROR: Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

PLAN_FILE="$(cd "$(dirname "$PLAN_FILE")" && pwd)/$(basename "$PLAN_FILE")"
PLAN_DIR="$(dirname "$PLAN_FILE")"
PLAN_BASENAME="$(basename "$PLAN_FILE" .md)"

# Extract title from first # heading
PLAN_TITLE="$(grep -m1 '^# ' "$PLAN_FILE" | sed 's/^# //' || echo "$PLAN_BASENAME")"

# --- Step 2: Derive review file path ---

REVIEW_DIR="$PLAN_DIR/reviews"
REVIEW_FILE="$REVIEW_DIR/${PLAN_BASENAME}-review.md"
mkdir -p "$REVIEW_DIR"

# --- Step 3: Prepare review file + count rounds ---

IS_NEW="false"
ROUND=1

if [[ ! -f "$REVIEW_FILE" ]]; then
  IS_NEW="true"
  cat > "$REVIEW_FILE" << EOF
# Plan Review: $PLAN_TITLE

**Plan File**: $PLAN_FILE
**Reviewer**: Codex
EOF
else
  # Count existing rounds
  ROUND=$(( $(grep -c '^## Round ' "$REVIEW_FILE" || echo "0") + 1 ))
fi

# --- Step 4: Extract previous issues summary + render prompt ---

TODAY="$(date +%Y-%m-%d)"
PROMPT_FILE="/tmp/codex-review-prompt-$(date +%s).md"

PRIOR_ISSUES_SECTION=""
PRIOR_ROUND_TRACKING=""

if [[ "$IS_NEW" == "false" ]]; then
  # Extract compact summary: R1: Issue 1 (Critical): Title | Location | Suggestion | Decision
  PRIOR_ISSUES="$(awk '
    /^## Round /{ round = $3 }
    /^#### Issue /{ title = $0; sub(/^#### /, "", title); loc = ""; sug = "" }
    /^\*\*Location\*\*:/{ loc = $0; sub(/^\*\*Location\*\*: */, "", loc) }
    /^\*\*Suggestion\*\*:/{ sug = $0; sub(/^\*\*Suggestion\*\*: */, "", sug) }
    /^\*\*Suggestion\*\*:/{ printf "- R%s: %s | Location: %s | Suggestion: %s\n", round, title, loc, sug }
  ' "$REVIEW_FILE")"

  # Extract apply decisions if present
  PRIOR_DECISIONS="$(awk '
    /^### Apply Decisions/{ capture = 1; next }
    /^### /{ capture = 0 }
    capture && /^\|/ && !/^\| *#/ && !/^\|---/{ print }
  ' "$REVIEW_FILE")"

  if [[ -n "$PRIOR_ISSUES" ]]; then
    PRIOR_ISSUES_SECTION="
<previous_issues>
The following issues were raised in previous rounds. Check whether the plan has been revised to address them.
Do not re-raise issues that have already been resolved unless the fix introduced new problems.
If an issue was explicitly rejected, do not re-raise it unless you have a substantially different argument.

$PRIOR_ISSUES"

    if [[ -n "$PRIOR_DECISIONS" ]]; then
      PRIOR_ISSUES_SECTION="$PRIOR_ISSUES_SECTION

Apply decisions from previous rounds (Accepted/Rejected with reasons):
$PRIOR_DECISIONS"
    fi

    PRIOR_ISSUES_SECTION="$PRIOR_ISSUES_SECTION
</previous_issues>"
  fi

  PRIOR_ROUND_TRACKING='### Previous Round Tracking
| # | Issue | Status | Notes |
|---|-------|--------|-------|
{For each previous issue from the list above: issue number, title, Resolved/Partially Resolved/Unresolved/Wontfix, brief notes}

'
fi

cat > "$PROMPT_FILE" << PROMPT_EOF
<task>
Read the project's CLAUDE.md and/or AGENTS.md files first to understand the tech stack and conventions.
Then read the plan file at $PLAN_FILE and review it critically as an independent third-party reviewer.
This is review round $ROUND.
</task>
$PRIOR_ISSUES_SECTION

<operating_stance>
Default to skepticism. Your job is to find the strongest reasons this plan should not proceed as-is.
Do not give credit for good intent, partial solutions, or assumed follow-up work.
If something only works on the happy path, treat that as a real weakness.
Challenge assumptions, not just surface-level details.
</operating_stance>

<analysis_dimensions>
Choose the relevant dimensions based on the plan type:
- Architectural soundness: overdesign vs underdesign, module boundaries, single responsibility
- Technology choices: rationale, alternatives considered, compatibility with the existing project stack
- Completeness: missing scenarios, overlooked edge cases, dependency and impact scope
- Feasibility: implementation complexity, performance risks, migration and compatibility concerns
- Engineering quality: whether it follows the project's coding conventions and quality standards
- User experience: interaction flow, error/loading states, i18n when relevant
- Security: authentication, authorization, data validation when relevant
</analysis_dimensions>

<finding_bar>
Report only material findings. Each issue must answer:
1. What can go wrong if this plan is implemented as-is?
2. Where exactly in the plan is the problem? (section or paragraph reference)
3. What is the likely impact? (blocked implementation, runtime failure, maintenance burden, etc.)
4. What concrete change would fix it?
Use severity levels: Critical > High > Medium > Low > Suggestion.
Do not include vague concerns, stylistic preferences, or speculative problems without evidence from the plan.
</finding_bar>

<calibration_rules>
Prefer one strong finding over several weak ones.
Do not dilute serious issues with filler.
Aim for at least 10 material findings, but never pad with trivial issues to reach that number.
If the plan is genuinely solid, report fewer issues and say so directly.
</calibration_rules>

<grounding_rules>
Every finding must be defensible from the plan content, the project's CLAUDE.md / AGENTS.md, or your tool outputs.
Do not invent requirements, constraints, or failure modes that are not supported by the provided context.
If a concern depends on an assumption, state that explicitly and keep the severity honest.
</grounding_rules>

<verification_loop>
Before finalizing, verify that each finding is:
- tied to a concrete location in the plan
- material (not stylistic or cosmetic)
- actionable (someone knows exactly how to revise the plan based on your suggestion)
- not a duplicate of another finding
Remove any finding that fails these checks.
</verification_loop>

<structured_output_contract>
Append the current review round to $REVIEW_FILE (create the file if it does not exist).
Separate rounds with --- and append new rounds at the end. Use this exact format:

---

## Round $ROUND — $TODAY

### Overall Assessment
{2-3 sentence assessment — write like a terse ship/no-ship verdict, not a neutral recap}
**Rating**: {X}/10

${PRIOR_ROUND_TRACKING}### Issues
#### Issue 1 ({severity}): {title}
**Location**: {section or paragraph reference in the plan}
{issue description — what can go wrong and why}
**Suggestion**: {concrete improvement suggestion}

... (continue for all material findings)

### Positive Aspects
- {things the plan does well — be specific, not generic praise}

### Summary
{Top 3 key issues that must be addressed}
**Consensus Status**: NEEDS_REVISION / MOSTLY_GOOD / APPROVED
</structured_output_contract>
PROMPT_EOF

# --- Step 5: Invoke Codex ---

CODEX_MODEL_FLAG=""
CODEX_EFFORT_FLAG=""
[[ -n "$CODEX_MODEL" ]]  && CODEX_MODEL_FLAG="-m $CODEX_MODEL"
[[ -n "$CODEX_EFFORT" ]] && CODEX_EFFORT_FLAG="-c model_reasoning_effort=\"$CODEX_EFFORT\""

CODEX_STATUS="ok"
CODEX_ERROR=""
if command -v codex &>/dev/null; then
  # stdout suppressed: review is written to $REVIEW_FILE by Codex,
  # Claude only needs the metadata line below. stderr captured for error reporting.
  CODEX_ERROR=$(codex exec $CODEX_MODEL_FLAG $CODEX_EFFORT_FLAG --full-auto --skip-git-repo-check < "$PROMPT_FILE" 2>&1 >/dev/null) || CODEX_STATUS="error"
else
  CODEX_STATUS="fallback"
  CODEX_ERROR="Codex CLI not found in PATH"
fi

# On error or missing CLI, fall back: prompt file is preserved for manual use.
# Don't cat the prompt — it's already saved at $PROMPT_FILE and the path is
# included in the metadata, so Claude can inform the user without consuming tokens.
if [[ "$CODEX_STATUS" != "ok" ]]; then
  echo "--- CODEX_FALLBACK ---"
  [[ -n "$CODEX_ERROR" ]] && echo "Error: $CODEX_ERROR"
  echo "Review prompt saved at: $PROMPT_FILE"
fi

# --- Output metadata for Claude ---
# Escape error message for JSON
CODEX_ERROR_JSON=$(printf '%s' "$CODEX_ERROR" | head -c 500 | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()), end="")' 2>/dev/null || echo '""')
echo ""
echo "--- REVIEW_METADATA ---"
echo "{\"plan_title\":\"$PLAN_TITLE\",\"plan_file\":\"$PLAN_FILE\",\"review_file\":\"$REVIEW_FILE\",\"round\":$ROUND,\"is_new\":$IS_NEW,\"codex_status\":\"$CODEX_STATUS\",\"codex_error\":$CODEX_ERROR_JSON,\"prompt_file\":\"$PROMPT_FILE\"}"
