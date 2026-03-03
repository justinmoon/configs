#!/usr/bin/env bash
set -euo pipefail

# Mark this agent's analysis as complete.
# If all agents are done, merge draft issues into issues/ and transition to position phase.
# Also hands off the turn automatically.

usage() {
    echo "Usage: end-analysis.sh <negotiation-dir> <agent-name>"
    exit 1
}

[[ $# -lt 2 ]] && usage

DIR="$1"
AGENT="$2"

# Mark this agent's analysis as complete
touch "$DIR/analysis/.${AGENT}-done"
echo "Analysis complete for $AGENT"

# Check how many agents are registered
AGENTS=()
while IFS= read -r line; do
    name=$(echo "$line" | sed 's/^- \([a-z][a-z0-9-]*\) .*/\1/')
    AGENTS+=("$name")
done < <(grep "^- [a-z]" "$DIR/agents.md")

# Check if all agents have completed analysis
ALL_DONE=true
for a in "${AGENTS[@]}"; do
    if [[ ! -f "$DIR/analysis/.${a}-done" ]]; then
        ALL_DONE=false
        break
    fi
done

if [[ "$ALL_DONE" == "true" ]]; then
    echo ""
    echo "All agents completed analysis. Merging issues..."

    # Merge all draft issues into issues/ with global sequential numbering.
    # Interleave: take one from each agent in round-robin to avoid clustering.
    # Collect all draft files per agent.
    declare -A AGENT_FILES
    for a in "${AGENTS[@]}"; do
        DRAFT_DIR="$DIR/issues-draft/$a"
        if [[ -d "$DRAFT_DIR" ]]; then
            FILES=()
            shopt -s nullglob
            for f in "$DRAFT_DIR/"*.md; do
                FILES+=("$f")
            done
            AGENT_FILES[$a]="${FILES[*]:-}"
        else
            AGENT_FILES[$a]=""
        fi
    done

    GLOBAL_NUM=0
    DONE=false
    ROUND=0

    while [[ "$DONE" != "true" ]]; do
        DONE=true
        for a in "${AGENTS[@]}"; do
            # Split the stored file list back into an array
            IFS=' ' read -ra FILES <<< "${AGENT_FILES[$a]:-}"
            if [[ "$ROUND" -lt "${#FILES[@]}" ]]; then
                DONE=false
                SRC="${FILES[$ROUND]}"
                GLOBAL_NUM=$((GLOBAL_NUM + 1))
                PADDED=$(printf "%02d" "$GLOBAL_NUM")
                # Extract the topic slug from the source filename
                BASENAME=$(basename "$SRC")
                SLUG=$(echo "$BASENAME" | sed 's/^[0-9]*-//')
                DEST="$DIR/issues/${PADDED}-${SLUG}"
                cp "$SRC" "$DEST"
                echo "  Merged: $BASENAME -> ${PADDED}-${SLUG} (from $a)"
            fi
        done
        ROUND=$((ROUND + 1))
    done

    echo ""
    echo "Merged $GLOBAL_NUM issues total."
    echo "Transitioning to position phase."
    echo "positions" > "$DIR/phase.md"
else
    echo "Waiting for other agents to complete analysis."
fi

# Hand off turn to next agent
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/hand-off.sh" "$DIR" "$AGENT"
