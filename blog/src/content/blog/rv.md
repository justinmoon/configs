---
title: "Reviewing AI-Generated Code with `rv`"
description: "A simple tool to review all git changes at once when working with coding agents"
date: 2024-10-31
---

AI coding agents create a lot of files fast. When you're ready to review before committing, `git diff` doesn't show untracked files. I needed one command to see everything: staged, unstaged, and new files.

```bash
rv              # Review with delta (default)
rv -d           # Review with difftastic
```

[Delta](https://github.com/dandavison/delta) is fast with side-by-side diffs and syntax highlighting. [Difftastic](https://difftastic.wilfred.me.uk/) understands syntax trees and shows structural changes, useful when the agent refactors code. I use delta for quick scans, difftastic when I need to see what actually changed versus what just moved.

The script pipes all diffs through delta by default. With the `-d` flag, it uses `GIT_EXTERNAL_DIFF` for tracked files and calls `difft` directly on untracked files.

```bash
#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat << EOF
rv - Review all git changes (staged, unstaged, and untracked files)

Usage: rv [OPTIONS]

Options:
    -d, --difft         Use difftastic instead of delta
    -h, --help          Show this help message

Examples:
    rv                  # Review with delta (default)
    rv -d               # Review with difftastic
EOF
    exit 0
}

# Parse arguments
USE_DIFFT=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--difft)
            USE_DIFFT=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use 'rv --help' for usage information"
            exit 1
            ;;
    esac
done

if [ "$USE_DIFFT" = true ]; then
    # Use difftastic as external diff tool
    export GIT_EXTERNAL_DIFF=difft
    
    # Show all changes with difftastic
    git diff HEAD
    
    # Untracked files - compare each against /dev/null
    git ls-files --others --exclude-standard | while read -r file; do
        if [ -f "$file" ]; then
            echo "=== New file: $file ==="
            difft /dev/null "$file" 2>/dev/null || true
        fi
    done
else
    # Use delta (pipe all diffs together)
    {
        # Staged and unstaged changes
        git diff HEAD 2>/dev/null || true
        
        # Untracked files
        git ls-files --others --exclude-standard | while read -r file; do
            git diff --no-index /dev/null "$file" 2>/dev/null || true
        done
    } | delta
fi
```
