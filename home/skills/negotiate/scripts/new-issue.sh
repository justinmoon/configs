#!/usr/bin/env bash
set -euo pipefail

# Create a new issue file with the next available number.
# Prevents duplicate numbering when multiple agents file issues.

usage() {
    echo "Usage: new-issue.sh <negotiation-dir> <short-topic>"
    echo ""
    echo "  short-topic: kebab-case topic name (e.g., 'auth-method')"
    echo ""
    echo "Creates issues/NN-<short-topic>.md with the next available number."
    echo "Prints the created filename to stdout."
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
TOPIC="$2"

if [[ ! -d "$DIR/issues" ]]; then
    echo "Error: No negotiation found at $DIR"
    exit 2
fi

# Validate topic (lowercase, hyphens, numbers)
if ! echo "$TOPIC" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Topic must be lowercase alphanumeric with hyphens, got: $TOPIC"
    exit 2
fi

# Find the next available number
shopt -s nullglob
MAX=0
for f in "$DIR/issues/"*.md; do
    BASENAME=$(basename "$f")
    NUM=$(echo "$BASENAME" | grep -oE '^[0-9]+' || echo 0)
    if [[ "$NUM" -gt "$MAX" ]]; then
        MAX="$NUM"
    fi
done

NEXT=$((MAX + 1))
PADDED=$(printf "%02d" "$NEXT")
FILENAME="${PADDED}-${TOPIC}.md"
FILEPATH="$DIR/issues/$FILENAME"

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
