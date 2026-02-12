---
name: negotiate
description: Multi-agent negotiation via filesystem. Say "negotiate about X at <path>" in two agents simultaneously — they auto-coordinate who initializes and who joins. Agents take turns resolving issues through structured positions until consensus.
---

# Agent Negotiate

Structured multi-agent negotiation protocol. Two or more AI agents resolve disagreements through turn-based written positions, converging to a single agreed document.

## Scripts

All scripts are in the `scripts/` subdirectory next to this SKILL.md file. Determine the absolute path based on where you read this file. We refer to it as `<scripts>` below.

## How to Use

You'll receive an instruction like: **"Negotiate about \<topic\> at \<path\>"**

The other agent receives the same instruction. You don't know who goes first — the skill handles it.

### Step 1: Try to Initialize

```bash
<scripts>/init.sh <negotiation-dir> 2 120
```

- **Exit 0** → You're the **initializer**. Go to Step 2a.
- **Exit 3** → Another agent already initialized. Go to Step 2b.

Use 2 agents and 120s registration window unless the user says otherwise.

### Step 2a: You're the Initializer

1. Write `<negotiation-dir>/topic.md` describing what's being negotiated.
2. Add your plan / source material to `<negotiation-dir>/sources/` (e.g. `sources/agent-alpha-plan.md`).
3. Create initial issues for points you think need discussion:
   ```bash
   FILENAME=$(<scripts>/new-issue.sh <negotiation-dir> <short-topic>)
   ```
   Then edit the created file. See [protocol reference](references/protocol.md) for the issue format.
4. Go to Step 3.

### Step 2b: You're Joining

Another agent is initializing. **Sleep 10 seconds** to let them finish writing topic/sources/issues, then go to Step 3.

On your first turn you can add your own source material to `sources/` and file additional issues.

### Step 3: Pick Your Agent Name

Read `<negotiation-dir>/agents.md`. Pick the first unused name from this sequence:
`agent-alpha`, `agent-beta`, `agent-gamma`, `agent-delta`, `agent-epsilon`

If `register.sh` fails because the name is already taken, try the next name.

### Step 4: Participation Loop

Follow this loop **exactly**. Do not deviate.

#### 4a: Register

```bash
<scripts>/register.sh <negotiation-dir> <your-agent-name>
```

#### 4b: Wait for All Agents

```bash
<scripts>/wait-for-start.sh <negotiation-dir> <your-agent-name>
```

This blocks until all expected agents register or the registration window closes.

#### 4c: Poll Loop

Repeat until done:

```bash
<scripts>/poll.sh <negotiation-dir> <your-agent-name>
```

- Exit code **0** → your turn. Go to 4d.
- Exit code **1** → not your turn. **Sleep 5 seconds**, then poll again.
- Exit code **2** → negotiation is done. Go to 4f.

**CRITICAL: NEVER stop polling to ask the user for confirmation or instructions. Your poll loop must run autonomously until `poll.sh` returns exit code 2 (done). Do not wait for human input between turns. Do not say "let me know when the other agent is ready." Just keep polling.**

#### 4d: Take Your Turn

When it's your turn:

1. **Read everything**: `topic.md`, all files in `sources/`, `issues/`, and `positions/`.

2. **Address ALL open issues** — not just ones you filed. On your first turn especially, you must write a position on every single issue that exists, including issues filed by other agents. Skipping issues wastes everyone's turns.

3. **For each OPEN issue** (where `positions/NN-topic.md` has `## Status: OPEN` or doesn't exist yet):
   - If no position file exists, create `positions/NN-topic.md`.
   - **Append** your position:
     ```markdown
     ## <your-name>'s position (round N)
     [Your reasoning, proposal, or acceptance]
     ```
   - If you **agree** with the latest proposal from another agent, change `## Status: OPEN` to `## Status: AGREED` and write the final decision text below it. **You may only mark AGREED if at least one other agent has already written a position on that issue.** You cannot self-agree on issues you filed alone.
   - If this is round N ≥ `max_rounds_per_agent` (from `meta.md`) without agreement, change Status to `## Status: ESCALATE` and summarize the disagreement.

4. **Raise new issues** if you find disagreements not yet captured:
   ```bash
   FILENAME=$(<scripts>/new-issue.sh <negotiation-dir> <short-topic>)
   ```

5. **Check overall status**:
   ```bash
   <scripts>/status.sh <negotiation-dir>
   ```

6. **If ALL issues are AGREED**: Write `<negotiation-dir>/final.md` — a clean, comprehensive merged document incorporating every agreed decision. Then:
   ```bash
   <scripts>/finish.sh <negotiation-dir>
   ```

7. **If issues remain OPEN**: Hand off:
   ```bash
   <scripts>/hand-off.sh <negotiation-dir> <your-agent-name>
   ```
   Return to 4c (poll again). **Keep polling. Do not stop.**

#### 4e: Done

When `poll.sh` returns exit code 2, the negotiation is complete. Read `final.md` and report the outcome to the user.

Copy the final document into the project:
```bash
mkdir -p ./todos
cp <negotiation-dir>/final.md ./todos/<descriptive-name>.md
```
Let the user know where you put it so they can point an agent at it for implementation.

## Turn Timeout

If an agent fails to act within `turn_timeout_seconds` (default: 600s / 10 minutes), `poll.sh` automatically skips the stalled agent and advances the turn.

## Negotiation Rules

- **Address all issues**: On every turn, write positions on ALL open issues, not just your own.
- **No self-agreement**: You cannot mark an issue AGREED unless another agent has written a position on it.
- **Be constructive**: Propose compromises, not just objections.
- **Be specific**: Reference exact text from source documents.
- **Be concise**: 1-3 paragraphs per position per issue.
- **Agree quickly on easy things**: Don't drag out obvious resolutions.
- **Focus on the output**: The goal is `final.md` — a single document everyone can work from.
- **Never edit another agent's positions**: Append only.
- **Use `new-issue.sh` for new issues**: Never manually number issue files.

## File Format Reference

See [the protocol reference](references/protocol.md) for detailed file formats and rules.

## Example Issue File

```markdown
# Issue: Authentication Method

## Question
Should the API use JWT tokens or session cookies?

## Position A (source-a)
JWT with refresh tokens.

## Position B (source-b)
httpOnly session cookies with Redis.
```

## Example Position File

```markdown
# Positions: Authentication Method

## agent-alpha's position (round 1)
JWT is the right choice because [reasoning]...
Proposed: JWT access tokens (15min) + refresh in httpOnly cookies.

## agent-beta's position (round 1)
Agreed. httpOnly cookie for refresh tokens addresses my security concern.

## Status: AGREED
JWT access tokens (15min) + refresh tokens (7d) in httpOnly secure cookies.
```
