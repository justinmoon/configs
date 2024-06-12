# Agent VM

Ephemeral microvms running [opencode](https://github.com/sst/opencode) for isolated coding tasks.

## Overview

Agent VM provides a way to run AI coding agents in isolated virtual machines. Each session:
- Clones a git repository into the VM
- Runs opencode with an optional prompt
- Persists all state to the host filesystem
- Can be stopped and resumed at any time

## Quick Start

```bash
# Set your API key
export ANTHROPIC_API_KEY="sk-..."

# Spawn a new agent session
agent-spawn --repo https://github.com/user/project --prompt "Fix the failing tests"

# List sessions
agent-list

# Attach to a running session
agent-attach <session-id>

# Stop a session (preserves files)
agent-stop <session-id>

# Resume a stopped session
agent-resume <session-id>
```

## Commands

### agent-spawn

Create and launch a new agent VM session.

```bash
agent-spawn --repo <url> [--prompt <text>] [--ref <branch>] [--port <port>]
```

Options:
- `--repo <url>` - Git repository URL (required)
- `--prompt <text>` - Initial prompt for opencode (optional)
- `--ref <branch>` - Git ref to checkout (default: main)
- `--port <port>` - SSH port (default: auto-assigned from 2222+)

### agent-attach

SSH into a running VM and attach to the tmux session.

```bash
agent-attach <session-id>
```

Use `Ctrl+B, D` to detach from tmux without stopping the agent.

### agent-list

List all sessions with their status.

```bash
agent-list          # Pretty table output
agent-list --json   # JSON output
```

### agent-stop

Stop a running VM. Session files are preserved.

```bash
agent-stop <session-id>
```

### agent-resume

Resume a stopped session with a new VM.

```bash
agent-resume <session-id>
```

## File Structure

Sessions are stored at `~/.agent-vm/sessions/`:

```
~/.agent-vm/
  sessions/
    {session-id}/
      meta.json           # Session metadata
      prompt.txt          # Initial prompt (if provided)
      env                 # Environment variables (API key)
      repo/               # Git repository clone
      opencode/           # XDG_DATA_HOME for opencode
        storage/          # opencode's native storage
          session/        # Session metadata
          message/        # Messages
```

## Architecture

```
HOST                                      MICROVM
────────────────────────────────────────────────────────────────
~/.agent-vm/sessions/{id}/                /session/ (mounted)
  ├── repo/           ──────────────────► /session/repo/
  ├── opencode/       ──────────────────► /session/opencode/
  └── meta.json

                                          tmux "agent"
                                            └── opencode
```

The VM mounts the session directory via 9p. All persistent state lives on
the host, making the VM completely disposable.

A symlink at `/tmp/agent-vm-session` points to the active session directory,
allowing runtime session selection without rebuilding the VM image.

## Environment Variables

- `ANTHROPIC_API_KEY` - API key for opencode (required)
- `AGENT_VM_SESSIONS` - Sessions directory (default: `~/.agent-vm/sessions`)

## Platform Support

All platforms use QEMU for consistent behavior:

- **macOS (aarch64)**: QEMU with HVF acceleration
- **macOS (x86_64)**: QEMU with HVF acceleration
- **Linux (x86_64)**: QEMU with KVM acceleration
- **Linux (aarch64)**: QEMU with KVM acceleration

## Standalone Usage

This directory is designed to be self-contained and extractable. To use it as a
standalone flake:

```bash
# From within this directory
nix develop  # Get all agent-* commands

# Or run directly
nix run .#agent-spawn -- --repo https://github.com/user/project

# Or install to profile
nix profile install .#agent-spawn
```

## Testing

Run the automated test to verify functionality:

```bash
cd agent-vm
ANTHROPIC_API_KEY="sk-..." nix run .#agent-test
```

## Current Limitations

1. **Single VM at a time**: The symlink approach (`/tmp/agent-vm-session`) means
   only one session can run at a time. Stop the current session before starting
   a new one.

2. **Port Allocation**: Basic sequential port allocation (2222-2300). No collision
   detection with external services.

3. **No Cleanup**: Sessions must be manually deleted with `rm -rf`.

4. **First build is slow**: The initial VM build downloads and compiles NixOS.
   Subsequent runs use the cached build.

## License

Same as parent repository.
