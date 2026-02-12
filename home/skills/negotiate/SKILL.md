---
name: negotiate
description: Multi-agent negotiation via filesystem. Say "negotiate about X at <path>" in two agents simultaneously — they auto-coordinate who initializes and who joins. Agents independently analyze divergences, then take turns resolving issues through adversarial positions until consensus.
---

# Agent Negotiate

Structured multi-agent negotiation protocol. Two or more AI agents resolve disagreements through turn-based written positions, converging to a single agreed document.

**Key design principles:**
- Neither agent "owns" the framing. Both independently identify divergences and file issues.
- Agreement requires adversarial testing first. You must argue against a position before accepting it.
- The final document must demonstrably account for unique ideas from all sources.

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
2. Add your plan / source material to `<negotiation-dir>/sources/` (e.g. `sources/agent-alpha-proposal.md`).
3. **Do NOT create issues yet.** Issues are filed during the Analysis Phase (Step 5).
4. Go to Step 3.

### Step 2b: You're Joining

Another agent is initializing. **Sleep 10 seconds** to let them finish writing topic/sources, then go to Step 3.

On your first turn you will add your own source material to `sources/`.

### Step 3: Pick Your Agent Name

Read `<negotiation-dir>/agents.md`. Pick the first unused name from this sequence:
`agent-alpha`, `agent-beta`, `agent-gamma`, `agent-delta`, `agent-epsilon`

If `register.sh` fails because the name is already taken, try the next name.

### Step 4: Register and Wait

#### 4a: Register

```bash
<scripts>/register.sh <negotiation-dir> <your-agent-name>
```

#### 4b: Wait for All Agents

```bash
<scripts>/wait-for-start.sh <negotiation-dir> <your-agent-name>
```

This blocks until all expected agents register or the registration window closes.

### Step 5: Analysis Phase

**This phase ensures both agents independently frame the issues.** Neither agent sees the other's issues before filing their own.

Check `<negotiation-dir>/phase.md` — it should say `analysis`.

#### 5a: Poll for Your Turn

```bash
<scripts>/poll.sh <negotiation-dir> <your-agent-name>
```

Same exit codes as the main loop (0=your turn, 1=wait, 2=done).

#### 5b: On Your Analysis Turn

1. If you haven't yet, add your source material to `sources/`.

2. **Read ALL source proposals in `sources/`.** Study them carefully.

3. **Write your divergence analysis** to `<negotiation-dir>/analysis/<your-agent-name>.md`. This MUST include:
   - A structured comparison of the proposals
   - Every point where the proposals diverge (different approaches, different scopes, things one includes that the other omits)
   - Unique elements from YOUR proposal that you think are important to preserve
   - Unique elements from the OTHER proposal that you think have merit

4. **File issues for every divergence** using:
   ```bash
   FILENAME=$(<scripts>/file-draft-issue.sh <negotiation-dir> <your-agent-name> <short-topic>)
   ```
   Then edit the created file. Each issue should capture one decision point.

   **CRITICAL: Do NOT read `issues-draft/` directories belonging to other agents.** File your issues based solely on your own analysis. The whole point is independent framing.

5. **Complete your analysis:**
   ```bash
   <scripts>/end-analysis.sh <negotiation-dir> <your-agent-name>
   ```
   This marks you done and hands off the turn. If all agents are done, it merges all draft issues into `issues/` and transitions to the position phase.

6. **Go back to 5a** (poll loop). When `phase.md` says `positions`, proceed to Step 6.

**CRITICAL: Keep polling through the analysis phase. Do NOT stop to ask the user anything.**

### Step 6: Position Phase

Check `<negotiation-dir>/phase.md` — it should say `positions`.

#### 6a: Poll Loop

Repeat until done:

```bash
<scripts>/poll.sh <negotiation-dir> <your-agent-name>
```

- Exit code **0** → your turn. Go to 6b.
- Exit code **1** → not your turn. **Sleep 5 seconds**, then poll again.
- Exit code **2** → negotiation is done. Go to 6d.

**CRITICAL: NEVER stop polling to ask the user for confirmation or instructions. Your poll loop must run autonomously until `poll.sh` returns exit code 2 (done). Do not wait for human input between turns. Do not say "let me know when the other agent is ready." Just keep polling.**

#### 6b: Take Your Turn

When it's your turn:

1. **Read everything**: `topic.md`, all files in `sources/`, `analysis/`, `issues/`, and `positions/`.

2. **Address ALL open issues** — not just ones you filed. On your first position turn especially, you must engage with every single issue that exists, including issues derived from the other agent's analysis. Skipping issues wastes everyone's turns.

3. **For each OPEN issue** (where `positions/NN-topic.md` has `## Status: OPEN` or doesn't exist yet):
   - If no position file exists, create `positions/NN-topic.md`.
   - **Append** your position:
     ```markdown
     ## <your-name>'s position (round N)
     [Your reasoning, proposal, or acceptance]
     ```
   - **Challenge-before-agree rule (MANDATORY):** You may NOT mark an issue AGREED until a challenge round has been written. Before agreeing, you (or the other agent) must first write a challenge entry that argues the strongest case AGAINST the position being considered. Use this format:
     ```markdown
     ## <your-name>'s challenge (round N)
     [Strongest argument AGAINST the proposal you're inclined to accept.
      Steel-man the opposing view. What could go wrong? What are we losing?]
     ```
     After a challenge has been written by at least one agent, the NEXT agent on their NEXT turn may mark AGREED — but only if the challenge has been adequately addressed.
   - To mark agreed: change `## Status: OPEN` to `## Status: AGREED` and write the final decision text below it. **You may only mark AGREED if (a) at least one other agent has already written a position on that issue AND (b) at least one challenge entry exists for that issue.**
   - If this is round N ≥ `max_rounds_per_agent` (from `meta.md`) without agreement, change Status to `## Status: ESCALATE` and summarize the disagreement.

4. **Raise new issues** if you find disagreements not yet captured:
   ```bash
   FILENAME=$(<scripts>/new-issue.sh <negotiation-dir> <short-topic>)
   ```

5. **Check overall status**:
   ```bash
   <scripts>/status.sh <negotiation-dir>
   ```

6. **If ALL issues are AGREED**: Write the coverage audit and final document (see Step 6c). Then:
   ```bash
   <scripts>/finish.sh <negotiation-dir>
   ```

7. **If issues remain OPEN**: Hand off:
   ```bash
   <scripts>/hand-off.sh <negotiation-dir> <your-agent-name>
   ```
   Return to 6a (poll again). **Keep polling. Do not stop.**

#### 6c: Coverage Audit and Final Document

Before writing `final.md`, you MUST write `<negotiation-dir>/coverage-audit.md`:

```markdown
# Coverage Audit

## Unique elements from <source-A>
- [Element]: INCLUDED / EXCLUDED (reason)
- [Element]: INCLUDED / EXCLUDED (reason)
...

## Unique elements from <source-B>
- [Element]: INCLUDED / EXCLUDED (reason)
- [Element]: INCLUDED / EXCLUDED (reason)
...

## Synthesis notes
[How competing ideas were merged or why one approach won]
```

For each source proposal, identify ideas/sections/details that are **unique to that source** (not present in the other). For each, state whether it made it into `final.md` and why or why not.

Then write `<negotiation-dir>/final.md` — a clean, comprehensive merged document incorporating every agreed decision.

#### 6d: Done

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

- **Independent analysis first**: File issues based on YOUR reading of the sources, not the other agent's framing.
- **Challenge before agree**: Every AGREED issue must have at least one challenge entry arguing against the accepted position. No rubber-stamping.
- **Address all issues**: On every turn, write positions on ALL open issues, not just your own.
- **No self-agreement**: You cannot mark an issue AGREED unless another agent has written a position on it.
- **Be adversarial, then constructive**: Your job is to find the best answer, not to be polite. Disagree when you have a better idea. Challenge weak reasoning. Then propose compromises.
- **Be specific**: Reference exact text from source documents.
- **Be concise**: 1-3 paragraphs per position per issue.
- **Focus on the output**: The goal is `final.md` — a single document everyone can work from.
- **Never edit another agent's positions**: Append only.
- **Use the right script for issues**: `file-draft-issue.sh` during analysis, `new-issue.sh` during positions.
- **Coverage matters**: The final document must account for unique ideas from ALL sources, not just the first-mover's.

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

## Example Position File (with challenge)

```markdown
# Positions: Authentication Method

## agent-alpha's position (round 1)
JWT is the right choice because [reasoning]...
Proposed: JWT access tokens (15min) + refresh in httpOnly cookies.

## agent-beta's challenge (round 1)
JWT has real downsides we shouldn't hand-wave: [steel-man argument against]...
The session cookie approach avoids [specific problems]...

## agent-beta's position (round 1)
Despite my challenge above, I think JWT is correct for this case because [reasoning that addresses the challenge]...
However, the refresh token storage should use [specific detail from source-b that wasn't in source-a].

## agent-alpha's position (round 2)
Agreed with beta's refinement on refresh token storage. The challenge about [X] is addressed by [Y].

## Status: AGREED
JWT access tokens (15min) + refresh tokens (7d) in httpOnly secure cookies. Refresh token storage uses [detail from source-b].
```
