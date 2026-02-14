---
name: consult
description: Multi-agent knowledge sharing via filesystem. Say "consult about X at <path> with N agents" in multiple agents simultaneously — they share findings so nobody duplicates work.
---

# Agent Consult

One-shot knowledge sharing between agents working on the same feature or bug. Every agent is equal -- no agent sets the topic or direction. Each agent writes a report of their progress, waits for the others, reads their reports, and gets back to work.

## Scripts

All scripts are in the `scripts/` subdirectory next to this SKILL.md file. Determine the absolute path based on where you read this file. We refer to it as `<scripts>` below.

## How to Use

You'll receive an instruction like: **"Consult about \<topic\> at \<path\> with \<N\> agents"**

The other agents receive the same instruction. All agents are equal participants.

### Step 1: Initialize or Join

```bash
<scripts>/init.sh <consult-dir> <N> [timeout-secs]
```

- **Exit 0** → You created the directory.
- **Exit 3** → Another agent already created it. That's fine, proceed.

Default timeout is 120 seconds.

### Step 2: Pick Your Agent Name

Pick the first unused name from this sequence:
`agent-alpha`, `agent-beta`, `agent-gamma`, `agent-delta`, `agent-epsilon`

Check `<consult-dir>/agents.md` to see which are taken.

### Step 3: Register

```bash
<scripts>/register.sh <consult-dir> <your-agent-name>
```

If the name is taken, try the next one in the sequence.

### Step 4: Post Your Report

Write a report of your progress so far. Create finding files using:

```bash
FILEPATH=$(<scripts>/post.sh <consult-dir> <your-agent-name> <short-topic>)
```

Then write your content to the printed filepath. Post as many files as you need.

**Every report MUST start with a header section like this:**

```markdown
# <Title>

## Working Directory
`~/code/pika/worktrees/audio-2`

## Files Modified
- `crates/pika-media/src/network.rs` -- rewrote NetworkRelay to worker thread pattern
- `rust/tests/e2e_local_marmotd_call.rs` -- new, parameterized e2e test

## Files Investigated (not modified)
- `rust/src/core/call_control.rs` -- call invite serialization
- `rust/src/core/mod.rs` -- event routing

## Summary
One-paragraph summary of your findings.
```

The working directory and file lists are critical -- other agents and the user need to know exactly where your changes are without reading your entire report.

**After the header, include the details:**
- What you've investigated so far
- What you've tried and what happened
- Root causes or hypotheses you've identified
- What you're planning to do next
- Anything that would save another agent from redoing your work

**Be specific.** Include file paths, function names, error messages, line numbers, stack traces.

### Step 5: Mark Ready

When you've posted your report:

```bash
<scripts>/ready.sh <consult-dir> <your-agent-name>
```

### Step 6: Wait for Others

Poll until everyone has checked in:

```bash
<scripts>/poll.sh <consult-dir> <your-agent-name>
```

- **Exit 0** → All agents are ready. Go to Step 7.
- **Exit 1** → Still waiting. Sleep 5 seconds, poll again.
- **Exit 2** → Timeout. Read what's there anyway. Go to Step 7.

**Keep polling. Do not stop to ask the user. Do not wait for human input.**

### Step 7: Read Everyone's Reports

```bash
<scripts>/read-all.sh <consult-dir> <your-agent-name>
```

This prints all reports from other agents (not your own). Read carefully.

### Step 8: Return to Your Task

You now know what the other agents know. Incorporate their findings into your work. Avoid re-investigating things they've already covered. Focus on what's left.

**That's it. The consultation is over.**

## Directory Structure

```
consult-dir/
├── meta.md                  # Config: expected agents, timeout
├── agents.md                # Registered agents
└── findings/
    ├── agent-alpha/
    │   ├── .ready           # Marker: done posting
    │   ├── 01-initial.md
    │   └── 02-root-cause.md
    └── agent-beta/
        ├── .ready
        └── 01-findings.md
```

## Rules

1. **All agents are equal.** No agent sets the topic or frames the direction. Each agent independently reports what they know.
2. **Write to your own directory only.** Never write to another agent's `findings/` subdirectory.
3. **Be specific.** File paths, function names, error messages, line numbers. Vague summaries waste everyone's time.
4. **Don't duplicate.** After reading others' reports, don't re-investigate the same things.
5. **Keep polling.** Never stop the poll loop to ask the user for input.
6. **One-shot.** This is a single round of sharing. Post, wait, read, done.
