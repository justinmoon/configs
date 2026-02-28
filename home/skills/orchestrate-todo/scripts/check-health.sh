#!/usr/bin/env bash
set -euo pipefail

# Usage: check-health.sh <coord-dir> <impl-pid> <rev1-pid> [rev2-pid]
# Prints structured status. Exit codes:
#   0 = healthy
#   1 = warning (stale heartbeat, repeated rework)
#   2 = critical (dead process, stuck)
#   3 = done

[[ $# -lt 3 ]] && { echo "Usage: check-health.sh <coord-dir> <impl-pid> <rev1-pid> [rev2-pid]"; exit 1; }

DIR="$1"
IMPL_PID="$2"
REV1_PID="$3"
REV2_PID="${4:-}"

issues=()
severity=0  # 0=ok, 1=warn, 2=critical, 3=done

# State check
state="$(cat "$DIR/state.md" 2>/dev/null | tr -d '[:space:]')"
if [[ "$state" == "done" ]]; then
    echo "STATUS done"
    exit 3
fi

# Process liveness
if ! kill -0 "$IMPL_PID" 2>/dev/null; then
    issues+=("implementer process dead (pid $IMPL_PID)")
    severity=2
fi
if ! kill -0 "$REV1_PID" 2>/dev/null; then
    issues+=("reviewer-1 process dead (pid $REV1_PID)")
    severity=2
fi
if [[ -n "$REV2_PID" ]] && ! kill -0 "$REV2_PID" 2>/dev/null; then
    issues+=("reviewer-2 process dead (pid $REV2_PID)")
    severity=2
fi

# Heartbeat staleness
if [[ -f "$DIR/heartbeats/implementer.epoch" ]]; then
    last="$(cat "$DIR/heartbeats/implementer.epoch" | head -1)"
    now="$(date -u +%s)"
    age=$(( now - last ))
    if [[ "$age" -gt 300 ]]; then
        issues+=("implementer heartbeat stale (${age}s)")
        [[ "$severity" -lt 1 ]] && severity=1
    fi
fi

# Progress counts
requests="$(find "$DIR/requests" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')"
decisions="$(find "$DIR/decisions" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')"
pending=$(( requests - decisions ))

# Repeated rework detection
for req in "$DIR/requests"/*.md; do
    [[ -f "$req" ]] || continue
    step_base="$(basename "$req" .md | sed 's/-round-[0-9]*//')"
    round_count="$(find "$DIR/requests" -name "${step_base}-round-*.md" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$round_count" -ge 3 ]]; then
        issues+=("step $step_base has $round_count rework rounds")
        [[ "$severity" -lt 1 ]] && severity=1
    fi
done

echo "STATUS $state"
echo "PROGRESS $decisions/$requests steps decided ($pending pending)"
echo "SEVERITY $severity"
for issue in "${issues[@]+"${issues[@]}"}"; do
    echo "ISSUE $issue"
done

exit "$severity"
