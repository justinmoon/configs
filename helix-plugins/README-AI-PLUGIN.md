# Helix AI Coding Assistant Plugin

An AI-powered coding assistant for Helix editor using the Steel plugin system.

## Current Status

**Phase 1**: Basic demo implementation
- ✅ Prompt modal for AI requests
- ✅ Context gathering (selection, file path)
- ⏳ Shell execution (needs integration with Helix pipe commands)
- ⏳ Response parsing and insertion

## Architecture

### Components

1. **ai-simple.scm** - Main plugin file
   - Provides `:ai-simple-assist` command
   - Bound to `Ctrl+a` in normal mode
   - Opens prompt for user input
   - Shows context information (for now)

2. **bin/helix-ai** - External AI wrapper script
   - Fish shell script that calls `llm` CLI
   - Can be replaced with any AI tool (aider, openai, etc.)
   - Formats prompt and context for AI consumption

### How It Works

```
User presses Ctrl+a
  ↓
Helix opens prompt modal
  ↓
User types request: "add error handling"
  ↓
Plugin gathers context:
  - Current selection
  - File path  
  - Surrounding code (TODO)
  ↓
Calls helix-ai script with context
  ↓
AI processes and returns response
  ↓
Plugin inserts response at cursor
```

## Installation

1. Plugin is already loaded via `init.scm`:
   ```scheme
   (require "./ai-simple.scm")
   ```

2. Keybinding already configured:
   ```scheme
   (add-global-keybinding
     (hash "normal" (hash "C-a" ":ai-simple-assist")))
   ```

3. Ensure `llm` CLI is installed:
   ```bash
   # llm is already in your PATH
   which llm  # Should show: /etc/profiles/per-user/justin/bin/llm
   ```

## Usage

1. **Basic AI Request**:
   - Press `Ctrl+a` in normal mode
   - Type your request: "refactor this function"
   - Press Enter
   - AI response will be inserted

2. **Edit Selection**:
   - Select code with visual mode
   - Press `Ctrl+a`
   - Type: "add error handling"
   - AI will see your selection as context

## Next Steps

### Phase 2: Real AI Integration

The current limitation is executing shell commands from Steel. Options:

#### Option A: Use Helix's shell-pipe command

Steel can call Helix typed commands. We need to:

```scheme
;; Call helix's :pipe command with our AI script
(helix.static.run-typed-command 
  (string-append ":pipe helix-ai \"" (escape-quotes prompt) "\""))
```

Need to find the Steel API for calling typed commands.

#### Option B: Pre-execute and pipe via temp file

```scheme
;; 1. Write selection to temp file
;; 2. Call :pipe-to with helix-ai script  
;; 3. Replace selection with output
```

#### Option C: Use Steel's process spawning (if available)

Check if Steel has built-in process spawning we haven't discovered yet.

### Phase 3: Advanced Features

Once basic AI calls work:

1. **Split pane UI** - Show AI response in preview pane before applying
2. **Multi-turn conversation** - Keep context across requests
3. **Diff view** - Show proposed changes as diff
4. **Undo/redo** - Proper undo support for AI changes
5. **Model selection** - Switch between models
6. **Custom prompts** - User-defined prompt templates

## Development

### Testing the Plugin

1. **Syntax check**:
   ```bash
   # Helix will show errors on startup if syntax is wrong
   hx  # Watch for Steel errors in status line
   ```

2. **Manual testing**:
   ```bash
   # Open any file
   hx test.rs
   
   # Press Ctrl+a
   # Type: "test request"
   # Should see demo response
   ```

3. **Check logs**:
   ```bash
   # Helix logs go to stderr
   hx 2> helix-errors.log
   ```

### Available Steel APIs

From the Helix codebase, we have:

```scheme
;; Selection and cursor
(current-selection->string)  ; Get selected text
(cx->current-file)           ; Get file path
(get-current-line-number)    ; Current line

;; Insertion and editing
(insert_string "text")       ; Insert at cursor
(helix.static.insert_mode)   ; Switch to insert mode
(helix.static.command_mode)  ; Switch to normal mode
(helix.static.delete_selection) ; Delete selection
(helix.static.select_all)    ; Select all

;; UI
(set-status! "message")      ; Show status message
(set-error! "error")         ; Show error message
(push-component! component)  ; Push UI component

;; Prompts
(prompt "text" callback)     ; Create prompt modal
```

### Extending the Plugin

**Add new commands**:

```scheme
(define (ai-refactor)
  (push-component!
    (prompt "Refactor how? "
      (lambda (instruction)
        ;; Your implementation
        ))))

(provide ai-refactor)  ; Export function
```

**Add to init.scm**:

```scheme
(add-global-keybinding
  (hash "normal" (hash "C-r" ":ai-refactor")))
```

## Alternative: Shell Script Approach

If direct Steel integration proves difficult, we can use shell scripts:

**~/.config/helix/ai-commands.sh**:
```bash
#!/bin/bash
# Add Helix menu items for AI commands

case "$1" in
  "refactor")
    hx --pipe "helix-ai 'refactor this code'"
    ;;
  "explain")
    hx --pipe "helix-ai 'explain this code'"
    ;;
esac
```

Then create Helix key bindings to call shell scripts.

## Comparison to Other Editors

**VSCode Copilot**: Inline suggestions, ghost text
- Harder to implement in Helix (TUI limitations)
- Could use status line or inline hints

**Cursor**: Chat panel + inline edits
- Chat panel = Helix split pane with custom UI
- Inline edits = exact replacement with diff view

**Aider**: Terminal-based, git-aware
- Already works great with Helix via :terminal
- Plugin could integrate it directly

## Resources

- [Helix Steel Plugin Docs](https://github.com/helix-editor/helix/tree/master/helix-term/src/commands/engine/steel)
- [Steel Language](https://github.com/mattwparas/steel)
- [LLM CLI](https://github.com/simonw/llm)
- [Aider](https://github.com/paul-gauthier/aider)

## Contributing

The plugin is in `~/configs/helix-plugins/ai-simple.scm`. 

To test changes:
1. Edit the file
2. Restart Helix
3. Test with Ctrl+a

The main challenge is figuring out how to execute shell commands from Steel. Any help appreciated!
