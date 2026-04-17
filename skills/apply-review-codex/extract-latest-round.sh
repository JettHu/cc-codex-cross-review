#!/usr/bin/env bash
# extract-latest-round.sh — Extract only the latest review round from a review file.
#
# Usage:
#   extract-latest-round.sh <review-file-path>
#
# Output:
#   The content of the latest "## Round N" section to stdout.
#   Metadata JSON on the last line after "--- ROUND_METADATA ---".

set -euo pipefail

REVIEW_FILE="${1:?Usage: extract-latest-round.sh <review-file-path>}"

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo "ERROR: Review file not found: $REVIEW_FILE" >&2
  exit 1
fi

# Find the last "## Round" heading line number
LAST_ROUND_LINE=$(grep -n '^## Round ' "$REVIEW_FILE" | tail -1 | cut -d: -f1)

if [[ -z "$LAST_ROUND_LINE" ]]; then
  echo "ERROR: No review rounds found in $REVIEW_FILE" >&2
  exit 1
fi

# Extract round number
ROUND_NUM=$(sed -n "${LAST_ROUND_LINE}p" "$REVIEW_FILE" | awk '{print $3}')

# Count total issues in this round
ISSUE_COUNT=$(tail -n +"$LAST_ROUND_LINE" "$REVIEW_FILE" | grep -c '^#### Issue ' || echo "0")

# Output the latest round content
tail -n +"$LAST_ROUND_LINE" "$REVIEW_FILE"

# Output metadata
echo ""
echo "--- ROUND_METADATA ---"
echo "{\"round\":$ROUND_NUM,\"issue_count\":$ISSUE_COUNT,\"review_file\":\"$REVIEW_FILE\"}"
