# Negotiation Protocol Reference

## Directory Structure

```
negotiation/
├── meta.md              # Config: expected agents, timing, max rounds
├── topic.md             # What is being negotiated
├── agents.md            # Registered agents (append-only)
├── turn.md              # Current turn holder (one word)
├── phase.md             # Current phase: "analysis" or "positions"
├── .turn-started        # Internal: timestamp for timeout detection
├── sources/             # Source documents to reconcile
│   ├── agent-alpha-proposal.md
│   └── agent-beta-proposal.md
├── analysis/            # Per-agent divergence analyses
│   ├── agent-alpha.md   # Alpha's independent analysis of divergences
│   ├── agent-beta.md    # Beta's independent analysis of divergences
│   ├── .agent-alpha-done  # Marker: alpha completed analysis
│   └── .agent-beta-done   # Marker: beta completed analysis
├── issues-draft/        # Private issue staging (analysis phase only)
│   ├── agent-alpha/     # Alpha's independently-filed issues
│   │   ├── 01-foo.md
│   │   └── 02-bar.md
│   └── agent-beta/      # Beta's independently-filed issues
│       ├── 01-baz.md
│       └── 02-qux.md
├── issues/              # Merged issues (populated after analysis phase)
│   └── NN-topic.md      # Sequentially numbered, interleaved from all agents
├── positions/           # Agent positions on each issue
│   └── NN-topic.md      # Matches issue filename
├── coverage-audit.md    # Required before final.md
└── final.md             # Final merged document (written at end)
```

## Phases

### Analysis Phase (`phase.md` = "analysis")

Each agent gets one turn to:
1. Read all source proposals
2. Write their divergence analysis to `analysis/<agent-name>.md`
3. File issues into `issues-draft/<agent-name>/` using `file-draft-issue.sh`
4. Run `end-analysis.sh` to mark done and hand off

**Agents must NOT read each other's `issues-draft/` directories.** The point is independent framing.

When all agents complete analysis, `end-analysis.sh` merges all draft issues into `issues/` with global sequential numbering (interleaved round-robin from each agent to avoid clustering) and sets `phase.md` to "positions".

### Position Phase (`phase.md` = "positions")

Standard turn-based negotiation. Agents write positions on all open issues, challenge before agreeing, and converge toward `final.md`.

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

**Always use `file-draft-issue.sh` during analysis phase and `new-issue.sh` during position phase** — they auto-assign numbers and prevent conflicts.

## Divergence Analysis Format

```markdown
# Divergence Analysis: <agent-name>

## Source Proposals Reviewed
- sources/agent-alpha-proposal.md
- sources/agent-beta-proposal.md

## Points of Agreement
[Areas where both proposals align — brief, don't belabor these]

## Divergences
### 1. [Topic]
- **Source A says**: [specific detail]
- **Source B says**: [specific detail]
- **My assessment**: [which approach is stronger and why]

### 2. [Topic]
...

## Unique Elements at Risk of Being Lost
### From source A (not in source B):
- [Element]: [why it matters or doesn't]

### From source B (not in source A):
- [Element]: [why it matters or doesn't]
```

## Position File Format

```markdown
# Positions: [Short Title]

## [agent-name]'s position (round N)
[Their argument, proposal, or acceptance]

## [agent-name]'s challenge (round N)
[Steel-man argument AGAINST the position they'd accept]

## [other-agent]'s position (round N)
[Their response, addressing the challenge]

## Status: OPEN | AGREED | ESCALATE
[If AGREED: the final decision text]
[If ESCALATE: summary of disagreement for human review]
```

## Challenge-Before-Agree Rule

**No issue may be marked AGREED without at least one challenge entry.**

A challenge entry uses this format:
```markdown
## <agent-name>'s challenge (round N)
```

The challenge must:
1. Argue the strongest case AGAINST the position being considered
2. Steel-man the opposing view — what's the best version of the rejected approach?
3. Identify what's being lost or what could go wrong with the accepted approach

After a challenge exists, the NEXT agent on their NEXT turn may mark AGREED if the challenge has been adequately addressed (either directly rebutted or acknowledged as an acceptable tradeoff).

**Purpose:** This prevents rubber-stamping. If you can't articulate a good argument against a position, you haven't thought about it hard enough.

## Coverage Audit Format

Required before `final.md`. Written to `coverage-audit.md`.

```markdown
# Coverage Audit

## Unique elements from [source-A filename]
- [Section/idea/detail]: INCLUDED / EXCLUDED (reason)
...

## Unique elements from [source-B filename]
- [Section/idea/detail]: INCLUDED / EXCLUDED (reason)
...

## Synthesis notes
[How competing approaches were merged, why one won, what was combined]
```

For each source, identify content **unique to that source** (not present in the other). Every such element must be accounted for — either included in `final.md` or explicitly excluded with a reason.

**Purpose:** This prevents the first-mover's proposal from becoming the default skeleton with the second proposal's unique content silently dropped.

## Rules

1. **Independent analysis**: File issues based on YOUR reading of the sources during analysis phase. Do not read other agents' draft issues.
2. **Challenge before agree**: No issue may be marked AGREED without at least one challenge entry from any agent.
3. **Append only**: Never edit another agent's positions. Only append your own.
4. **Full positions**: State your reasoning, not just agree/disagree.
5. **One issue per file**: Don't merge issues.
6. **Address all issues**: On every turn, write positions on ALL open issues — not just ones derived from your analysis. Skipping issues filed by other agents wastes turns.
7. **No self-agreement**: You may only change Status to AGREED if at least one other agent has already written a position on that issue.
8. **Escalation**: After max rounds without agreement, change Status to ESCALATE.
9. **Coverage audit required**: Before writing `final.md`, write `coverage-audit.md` accounting for unique content from all sources.
10. **Finish**: When ALL issues are AGREED, coverage audit is written, the agent whose turn it is writes `final.md` and runs `finish.sh`.
11. **Never stop polling**: The poll loop must run autonomously until the negotiation is done (exit code 2). Never pause to ask the user.

## Turn Mechanics

- `turn.md` contains one word: an agent name, `registration`, or `done`
- Only the named agent may write to issues/, positions/, or analysis/
- After finishing your turn, run `hand-off.sh` (position phase) or `end-analysis.sh` (analysis phase) to pass to next agent
- Agents rotate in registration order
- If an agent is inactive for `turn_timeout_seconds`, the next polling agent skips them

## Round Counting

Each time an agent writes a position on an issue, it's a "round" for that issue.
Each time an agent writes a challenge on an issue, it counts as activity but not a position round.
Max rounds per agent (from meta.md) applies per-issue to position entries only.

## Scripts

| Script | Phase | Purpose |
|--------|-------|---------|
| `init.sh <dir> <n> [window]` | Setup | Create negotiation directory |
| `register.sh <dir> <name>` | Setup | Register an agent |
| `wait-for-start.sh <dir> <name>` | Setup | Block until registration complete |
| `file-draft-issue.sh <dir> <name> <topic>` | Analysis | File issue in agent's private staging area |
| `end-analysis.sh <dir> <name>` | Analysis | Mark analysis done; merge issues if all agents done; hand off |
| `poll.sh <dir> <name>` | Both | Check if it's your turn (0=yes, 1=no, 2=done) |
| `new-issue.sh <dir> <topic>` | Positions | Create a new issue file in issues/ |
| `hand-off.sh <dir> <name>` | Positions | Pass turn to next agent |
| `status.sh <dir>` | Positions | Print all issues and resolution status |
| `finish.sh <dir>` | Positions | Mark negotiation done (validates all agreed + challenge rule + coverage audit + final.md) |
