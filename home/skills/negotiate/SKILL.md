---
name: negotiate
description: Multi-agent negotiation via filesystem. Agents take turns resolving issues through structured positions until consensus or escalation. Use when multiple AI agents need to reconcile differing specs, designs, or approaches into a single agreed document.
---

# Agent Negotiate

Structured multi-agent negotiation protocol. Two or more AI agents resolve disagreements through turn-based written positions on specific issues, converging to a single agreed document.

## Quick Start

You'll be told either to **initialize** a negotiation or to **join** an existing one. You'll be given:
- A **negotiation directory** path
- Your **agent name** (lowercase, hyphens only, e.g., `agent-alpha`)
- The path to these **skill scripts**

## If Initializing

1. Run the init script:
   ```bash
   <scripts>/init.sh <negotiation-dir> <num-agents> [registration-window-secs]
   ```

2. Write `<negotiation-dir>/topic.md` describing what's being negotiated.

3. Add source documents to `<negotiation-dir>/sources/`.

4. Create initial issues in `<negotiation-dir>/issues/`. **Use the `new-issue.sh` script** to get auto-numbered filenames:
   ```bash
   FILENAME=$(<scripts>/new-issue.sh <negotiation-dir> <short-topic>)
   ```
   Then edit `<negotiation-dir>/issues/$FILENAME` with the issue content. See [protocol reference](references/protocol.md) for the issue file format.

5. Then proceed to the **Participation Loop** below.

## Participation Loop

Follow this loop **exactly**. Do not deviate.

### Step 1: Register

```bash
<scripts>/register.sh <negotiation-dir> <your-agent-name>
```

### Step 2: Wait for All Agents

```bash
<scripts>/wait-for-start.sh <negotiation-dir> <your-agent-name>
```

This blocks until all expected agents register or the registration window closes.

### Step 3: Poll Loop

Repeat until done:

```bash
<scripts>/poll.sh <negotiation-dir> <your-agent-name>
```

- Exit code **0** → your turn. Go to Step 4.
- Exit code **1** → not your turn. **Sleep 5 seconds**, then poll again.
- Exit code **2** → negotiation is done. Go to Step 6.

**CRITICAL: NEVER stop polling to ask the user for confirmation or instructions. Your poll loop must run autonomously until `poll.sh` returns exit code 2 (done). Do not wait for human input between turns. Do not say "let me know when the other agent is ready." Just keep polling.**

### Step 4: Take Your Turn

When it's your turn:

1. **Read everything**: `topic.md`, all files in `sources/`, `issues/`, and `positions/`.

2. **Address ALL open issues** — not just ones you filed. On your first turn especially, you must write a position on every single issue that exists, including issues filed by other agents. Skipping issues wastes everyone's turns.

3. **For each OPEN issue** (where `positions/NN-topic.md` has `## Status: OPEN` or doesn't exist yet):
   - If no position file exists, create `positions/NN-topic.md`.
   - **Append** your position. Format:
     ```markdown
     ## <your-name>'s position (round N)
     [Your reasoning, proposal, or acceptance]
     ```
   - If you **agree** with the latest proposal from another agent, change `## Status: OPEN` to `## Status: AGREED` and write the final decision text below it. **You may only mark AGREED if at least one other agent has already written a position on that issue.** You cannot self-agree on issues you filed alone.
   - If this is round N ≥ `max_rounds_per_agent` (from `meta.md`) without agreement, change Status to `## Status: ESCALATE` and summarize the disagreement.

4. **Raise new issues** if you find disagreements not yet captured. **Always use `new-issue.sh`** to create the file — this prevents duplicate numbering:
   ```bash
   FILENAME=$(<scripts>/new-issue.sh <negotiation-dir> <short-topic>)
   ```
   Then edit the created file with the issue content.

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
   Go back to Step 3.

### Step 5: Poll Again

After handing off, return to Step 3. **Keep polling. Do not stop.**

### Step 6: Done

When `poll.sh` returns exit code 2 (done), the negotiation is complete. Read `final.md` and report the outcome to the user.

## Turn Timeout

If an agent fails to act within `turn_timeout_seconds` (default: 600s / 10 minutes), `poll.sh` automatically skips the stalled agent and advances the turn. This prevents the negotiation from blocking on an unresponsive agent.

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

## How to Prompt Other Agents

When telling another agent (or asking a user to tell another agent) to join, use this template:

```
Join the negotiation at <NEGOTIATION-DIR>.

Your agent name is "<AGENT-NAME>".

Use the negotiate skill. The skill scripts are at:
  <SCRIPTS-DIR>

Follow the skill instructions exactly:
1. Read <SCRIPTS-DIR>/../SKILL.md for the full protocol
2. Run: <SCRIPTS-DIR>/register.sh <NEGOTIATION-DIR> <AGENT-NAME>
3. Run: <SCRIPTS-DIR>/wait-for-start.sh <NEGOTIATION-DIR> <AGENT-NAME>
4. Poll in a loop: <SCRIPTS-DIR>/poll.sh <NEGOTIATION-DIR> <AGENT-NAME>
   - Exit 0 = your turn (read everything, write positions, hand off)
   - Exit 1 = not your turn (sleep 5, poll again)
   - Exit 2 = done
5. NEVER stop polling to ask for human input. Run autonomously.
6. When it's your turn, write positions on ALL open issues.
7. Use <SCRIPTS-DIR>/new-issue.sh <NEGOTIATION-DIR> <topic> to create new issues.
8. Use <SCRIPTS-DIR>/hand-off.sh <NEGOTIATION-DIR> <AGENT-NAME> when done with your turn.
9. When all issues are AGREED, write final.md and run <SCRIPTS-DIR>/finish.sh <NEGOTIATION-DIR>.
```

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
