# Consult Protocol Reference

## Directory Structure

```
consult-dir/
├── meta.md           # Config
├── agents.md         # Registered agents (append-only)
└── findings/
    └── <agent-name>/
        ├── .ready    # Marker: agent done posting
        └── NN-topic.md  # Finding files (auto-numbered)
```

## Meta Configuration (meta.md)

| Field | Default | Description |
|-------|---------|-------------|
| expected_agents | required | Number of agents to wait for |
| timeout_seconds | 120 | Max time to wait for all agents to be ready |
| poll_interval_seconds | 5 | How often agents should poll |

## Finding File Format

Every report **must** start with a structured header:

```markdown
# <Title>

## Working Directories
- `~/code/pika/worktrees/audio-2` -- media transport layer
- `~/code/openclaw-marmot` -- bot sidecar daemon

## Files Modified
- `pika: path/to/file.rs` -- short description of change
- `openclaw-marmot: path/to/other.rs` -- new, description

## Files Investigated (not modified)
- `pika: path/to/read-only.rs` -- what you looked at and why

## Summary
One-paragraph summary of findings.
```

List every repo/worktree you touched. Prefix file paths with the repo name when working across multiple repos. After the header, include whatever detail is useful: what was tried, what worked, what didn't, hypotheses, error messages, stack traces, etc.

## Lifecycle

1. **Init**: First agent creates directory with `init.sh`. Others get exit code 3 and join.
2. **Register**: Each agent picks a name and runs `register.sh`.
3. **Post**: Agents write findings to their own subdirectory using `post.sh`.
4. **Ready**: Agents mark themselves done with `ready.sh`.
5. **Poll**: Agents poll with `poll.sh` until all are ready or timeout.
6. **Read**: Agents read each other's findings with `read-all.sh`.
7. **Done**: Agents return to their original task.

## Concurrency

There are no turns. All agents can write simultaneously because each agent writes only to their own `findings/<agent-name>/` subdirectory. No locking is needed.

The only shared mutable files are `agents.md` (append-only) and `meta.md` (deadline appended once by first registrant). These are safe because appends are atomic at the filesystem level for short lines.

## Scripts

| Script | Purpose |
|--------|---------|
| `init.sh <dir> <n> [timeout]` | Create consultation directory |
| `register.sh <dir> <name>` | Register an agent |
| `post.sh <dir> <name> <topic>` | Create a new finding file, print its path |
| `ready.sh <dir> <name>` | Mark agent as done posting |
| `poll.sh <dir> <name>` | Check if all agents ready (0=yes, 1=wait, 2=timeout) |
| `read-all.sh <dir> <name>` | Print all other agents' findings |
