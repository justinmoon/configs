#!/usr/bin/env bash
set -euo pipefail

# Print negotiation status: all issues and their resolution status.

usage() {
    echo "Usage: status.sh <negotiation-dir>"
    exit 1
}

[[ $# -lt 1 ]] && usage

DIR="$1"

echo "=== Negotiation Status ==="
echo ""

# Turn
TURN=$(cat "$DIR/turn.md" 2>/dev/null | tr -d '[:space:]')
echo "Current turn: $TURN"
echo ""

# Agents
echo "Registered agents:"
grep "^- " "$DIR/agents.md" 2>/dev/null || echo "  (none)"
echo ""

# Participant uniqueness check (best-effort visibility for debugging)
PARTICIPANTS=$(grep "^- " "$DIR/agents.md" 2>/dev/null | sed -n 's/.*participant: \([^)]*\)).*/\1/p' || true)
if [[ -n "$PARTICIPANTS" ]]; then
    DUPS=$(printf "%s\n" "$PARTICIPANTS" | sort | uniq -d || true)
    if [[ -n "$DUPS" ]]; then
        echo "Participant identity warning: duplicate participant(s) detected"
        printf "  %s\n" "$DUPS"
        echo ""
    fi
fi

# Issues and positions
echo "Issues:"
TOTAL=0
AGREED=0
ESCALATED=0
OPEN=0

shopt -s nullglob
for issue in "$DIR/issues/"*.md; do
    TOTAL=$((TOTAL + 1))
    BASENAME=$(basename "$issue")
    TITLE=$(head -1 "$issue" | sed 's/^#* *//')

    # Check resolution status
    POS_FILE="$DIR/positions/$BASENAME"
    if [[ -f "$POS_FILE" ]]; then
        STATUS=$(grep "^## Status:" "$POS_FILE" | tail -1 | sed 's/^## Status: *//')
        case "$STATUS" in
            AGREED*) AGREED=$((AGREED + 1)); ICON="✅" ;;
            ESCALATE*) ESCALATED=$((ESCALATED + 1)); ICON="⚠️" ;;
            *) OPEN=$((OPEN + 1)); ICON="🔄" ;;
        esac
    else
        OPEN=$((OPEN + 1))
        STATUS="NO POSITIONS YET"
        ICON="📝"
    fi

    echo "  $ICON $BASENAME — $TITLE [$STATUS]"
done

if [[ "$TOTAL" -eq 0 ]]; then
    echo "  (no issues filed yet)"
fi

echo ""
echo "Summary: $TOTAL issues — $AGREED agreed, $OPEN open, $ESCALATED escalated"

# Check if done
if [[ "$TOTAL" -gt 0 ]] && [[ "$OPEN" -eq 0 ]] && [[ "$ESCALATED" -eq 0 ]]; then
    echo ""
    echo "🎉 All issues resolved! Ready for final document."
fi
