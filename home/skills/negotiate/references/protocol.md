# Negotiation Protocol Reference

## Directory Structure

```
negotiation/
├── meta.md          # Config: expected agents, timing, max rounds
├── topic.md         # What is being negotiated
├── agents.md        # Registered agents (append-only)
├── turn.md          # Current turn holder (one word)
├── .turn-started    # Internal: timestamp for timeout detection
├── sources/         # Source documents to reconcile
│   ├── doc-a.md
│   └── doc-b.md
├── issues/          # Issues to resolve (auto-numbered via new-issue.sh)
│   └── NN-topic.md  # Numbered issue files
├── positions/       # Agent positions on each issue
│   └── NN-topic.md  # Matches issue filename
└── final.md         # Final merged document (written at end)
```

## Meta Configuration (meta.md)

| Field | Default | Description |
|-------|---------|-------------|
| expected_agents | required | Number of agents to wait for |
| registration_window_seconds | 30 | Max time to wait for all agents |
| max_rounds_per_agent | 5 | Max position rounds per agent per issue |
| poll_interval_seconds | 5 | How often agents should poll |
| turn_timeout_seconds | 600 | Skip agent if inactive this long |

## Issue File Format

```markdown
# Issue: [Short Title]

## Question
What specific decision needs to be made?

## Context
Relevant background, references to source docs.

## Position A (source-a)
What source A says or implies.

## Position B (source-b)
What source B says or implies.
```

**Always use `new-issue.sh` to create issue files** — it auto-assigns the next available number and prevents duplicate numbering conflicts between agents.

## Position File Format

```markdown
# Positions: [Short Title]

## [agent-name]'s position (round N)
[Their argument, proposal, or acceptance]

## [other-agent]'s position (round N)
[Their response]

## Status: OPEN | AGREED | ESCALATE
[If AGREED: the final decision text]
[If ESCALATE: summary of disagreement for human review]
```

## Rules

1. **Append only**: Never edit another agent's positions. Only append your own.
2. **Full positions**: State your reasoning, not just agree/disagree.
3. **One issue per file**: Don't merge issues.
4. **New issues**: Use `new-issue.sh` to create new issue files. Never manually number them.
5. **Address all issues**: On every turn, write positions on ALL open issues — not just ones you filed. Skipping issues filed by other agents wastes turns.
6. **No self-agreement**: You may only change Status to AGREED if at least one other agent has already written a position on that issue. You cannot unilaterally agree on your own issues.
7. **Escalation**: After max rounds without agreement, change Status to ESCALATE.
8. **Finish**: When ALL issues are AGREED, the agent whose turn it is writes `final.md` and runs `finish.sh`.
9. **Never stop polling**: The poll loop must run autonomously until the negotiation is done (exit code 2). Never pause to ask the user.

## Turn Mechanics

- `turn.md` contains one word: an agent name, `registration`, or `done`
- Only the named agent may write to issues/ or positions/
- After finishing your turn, run `hand-off.sh` to pass to next agent
- Agents rotate in registration order
- If an agent is inactive for `turn_timeout_seconds`, the next polling agent skips them

## Round Counting

Each time an agent writes a position on an issue, it's a "round" for that issue.
Max rounds per agent (from meta.md) applies per-issue.

## Scripts

| Script | Purpose |
|--------|---------|
| `init.sh <dir> <n> [window]` | Create negotiation directory |
| `register.sh <dir> <name>` | Register an agent |
| `wait-for-start.sh <dir> <name>` | Block until registration complete |
| `poll.sh <dir> <name>` | Check if it's your turn (0=yes, 1=no, 2=done) |
| `hand-off.sh <dir> <name>` | Pass turn to next agent |
| `new-issue.sh <dir> <topic>` | Create a new issue file with auto-numbering |
| `status.sh <dir>` | Print all issues and resolution status |
| `finish.sh <dir>` | Mark negotiation done (validates all agreed + final.md exists) |
