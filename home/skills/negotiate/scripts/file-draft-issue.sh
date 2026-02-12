#!/usr/bin/env bash
set -euo pipefail

# Create an issue in this agent's private draft directory.
# Issues stay private until end-analysis.sh merges them.

usage() {
    echo "Usage: file-draft-issue.sh <negotiation-dir> <agent-name> <short-topic>"
    echo ""
    echo "  short-topic: kebab-case topic name (e.g., 'auth-method')"
    echo ""
    echo "Creates issues-draft/<agent-name>/NN-<short-topic>.md"
    echo "Prints the created filename to stdout."
    exit 1
}

[[ $# -lt 3 ]] && usage

DIR="$1"
AGENT="$2"
TOPIC="$3"

DRAFT_DIR="$DIR/issues-draft/$AGENT"
mkdir -p "$DRAFT_DIR"

# Validate topic (lowercase, hyphens, numbers)
if ! echo "$TOPIC" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Topic must be lowercase alphanumeric with hyphens, got: $TOPIC"
    exit 2
fi

# Find the next available number within this agent's drafts
shopt -s nullglob
MAX=0
for f in "$DRAFT_DIR/"*.md; do
    BASENAME=$(basename "$f")
    NUM=$(echo "$BASENAME" | grep -oE '^[0-9]+' || echo 0)
    if [[ "$NUM" -gt "$MAX" ]]; then
        MAX="$NUM"
    fi
done

NEXT=$((MAX + 1))
PADDED=$(printf "%02d" "$NEXT")
FILENAME="${PADDED}-${TOPIC}.md"
FILEPATH="$DRAFT_DIR/$FILENAME"

# Create the issue file with a template
cat > "$FILEPATH" << EOF
# Issue: [TODO: Short Title]

## Question
[TODO: What specific decision needs to be made?]

## Context
[TODO: Relevant background, references to source docs.]

## Position A
[TODO: What one source says or implies.]

## Position B
[TODO: What the other source says or implies.]
EOF

echo "$FILENAME"
