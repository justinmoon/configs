# configs repo bin scripts
# FIXME: broken on Mac
set -U fish_user_paths $HOME/configs/bin $HOME/code/agent-configs/bin $fish_user_paths
# set -U fish_user_paths $HOME/go/bin $fish_user_paths
set -x PATH $HOME/go/bin $PATH

# Nix direnv cache optimization
set -x NIX_DIR_ENV_CACHE 1

# Local secrets (API keys, etc.) - not checked into git
test -f ~/.secrets.fish && source ~/.secrets.fish

# zapstore
fish_add_path "/Users/justin/.zapstore"

# droid (factory.ai coding agent)
fish_add_path "$HOME/.local/bin"

# bun global packages
fish_add_path "$HOME/.bun/bin"

# cargo installed binaries
fish_add_path "$HOME/.cargo/bin"

# Aliases
alias wipe="clear && printf '\e[3J'"
alias c="cargo"
alias g="git"
alias j="just"
alias n="nvim"
alias e="exercism"
alias h="hx"
alias lg="lazygit"
alias oc="opencode"
alias rp="realpath"
alias nq="networkquality"
alias da="direnv allow"
alias glow="glow -p"

alias gk="git push"
alias gj="git pull"
alias gc="git commit"
alias gs="git squash"
alias gr="git rebase"
alias gm="git merge"
alias gl="git log"

# Create a new worktree and branch from within current git directory.
function ga
    set -l branch $argv[1]
    if test -z "$branch"
        set branch (gum input --placeholder "Branch name")
        if test -z "$branch"
            return 1
        end
    end
    set -l path "./worktrees/$branch"
    set -l abs_path (realpath -m "$path")

    mkdir -p ./worktrees
    git worktree add -b "$branch" "$path"
    or return 1

    # Check if we should open in a new tmux window
    if test -n "$TMUX"
        if gum confirm "Open in new tmux window?"
            tmux new-window -n "$branch" -c "$abs_path"
            sleep 0.3
            tmux send-keys -t "$branch" "direnv allow" Enter
        else
            cd "$path"
            direnv allow
            tmux rename-window "$branch"
        end
    else
        cd "$path"
        direnv allow
    end
end

# Remove worktree and branch from within active worktree directory.
function gd
    set -l cwd (pwd)
    set -l worktree (basename $cwd)
    set -l parent (dirname $cwd)

    # Protect: only works if we're inside a "worktrees" directory
    if test (basename $parent) != worktrees
        echo "Not inside a worktrees/ directory" >&2
        return 1
    end

    if not gum confirm "Remove worktree '$worktree' and branch?"
        return 0
    end

    # Check if we should kill the tmux window
    set -l kill_window 0
    if test -n "$TMUX"
        if gum confirm "Kill this tmux window?"
            set kill_window 1
        end
    end

    set -l root (dirname $parent)
    cd "$root"
    git worktree remove "worktrees/$worktree" --force
    git branch -D "$worktree"

    if test $kill_window -eq 1
        tmux kill-window
    else if test -n "$TMUX"
        tmux rename-window (basename $root)
    end
end

alias copy="xclip -selection clipboard"
alias y="pbcopy"

# AI command generator - inserts command into prompt
function ai
    set cmd (command ai $argv)
    if test -n "$cmd"
        commandline -r $cmd
        commandline -f repaint
    end
end

# Adjust resolutionn when switching between laptop and external monitor
alias laptop="xrandr --output Virtual-1 --mode 3024x1890"
alias desktop="xrandr --output Virtual-1 --mode 6880x2880"

# These look right with "View > Use All Displays in Full Screen", but mouse doesn't click accurately
alias multi="xrandr --output Virtual-1 --auto --output Virtual-2 --auto --below Virtual-1"
alias multi2="xrandr --output Virtual-1 --mode 6880x2880 --auto --output Virtual-2 --mode 3024x1890 --auto --below Virtual-1"

# So I don't have to move from home row
bind \ck up-or-search
bind \cj down-or-search

# Make direnv less noisy on startup
set -x DIRENV_LOG_FORMAT ""

# Direnv hook
eval (direnv hook fish)

# Custom FIDO2-capable SSH agent (macOS only)
# The default macOS ssh-agent can't prompt for YubiKey PIN/touch over forwarded connections
if test (uname) = Darwin
    set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent-fido.sock"
    # Only set askpass if keys require PIN (verify-required)
    # Our keys were generated without -O verify-required, so only touch is needed
    # set -gx SSH_ASKPASS "$HOME/configs/bin/ssh-askpass-fido"
    # set -gx SSH_ASKPASS_REQUIRE "prefer"
    set -gx DISPLAY ":0"

    # Start the agent if not already running
    if not test -S "$SSH_AUTH_SOCK"
        # Use OpenSSH agent from nix or system
        set -l agent_bin (command -v ssh-agent)
        if test -n "$agent_bin"
            eval ($agent_bin -a "$SSH_AUTH_SOCK" -c) >/dev/null 2>&1
        end
    end
end

# Homebrew
if test -d /opt/homebrew
    set -gx HOMEBREW_PREFIX /opt/homebrew
    set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
    set -gx HOMEBREW_REPOSITORY /opt/homebrew
    set -q PATH; or set PATH ''
    set -gx PATH /opt/homebrew/bin /opt/homebrew/sbin $PATH
    set -q MANPATH; or set MANPATH ''
    set -gx MANPATH /opt/homebrew/share/man $MANPATH
    set -q INFOPATH; or set INFOPATH ''
    set -gx INFOPATH /opt/homebrew/share/info $INFOPATH
end

# Colorscheme-managed integrations
set -l __colorscheme_state "$HOME/.local/state/colorscheme"

set -l __colorscheme_starship "$__colorscheme_state/starship.toml"
if test -f $__colorscheme_starship
    set -x STARSHIP_CONFIG $__colorscheme_starship
else if set -q STARSHIP_CONFIG
    set -e STARSHIP_CONFIG
end

set -l __colorscheme_fzf "$__colorscheme_state/fzf.txt"
if test -f $__colorscheme_fzf
    set -l __colorscheme_fzf_opts (cat $__colorscheme_fzf)
    set -x FZF_DEFAULT_OPTS $__colorscheme_fzf_opts
else
    set -x FZF_DEFAULT_OPTS "--color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#88C0D0 --color=fg:#E5E9F0,header:#88C0D0,info:#81A1C1,pointer:#81A1C1 --color=marker:#81A1C1,fg+:#ECEFF4,prompt:#81A1C1,hl+:#88C0D0 --color=border:#4C566A"
end

# Gum colorscheme integration (uses ANSI palette colors)
set -l __colorscheme_gum "$__colorscheme_state/gum.env"
if test -f $__colorscheme_gum
    # Source the gum environment variables
    while read -l line
        # Skip comments and empty lines
        if string match -q '#*' -- $line; or test -z "$line"
            continue
        end
        # Parse "export VAR=value" format
        set -l parsed (string replace 'export ' '' -- $line)
        set -l parts (string split '=' -- $parsed)
        if test (count $parts) -ge 2
            set -gx $parts[1] (string join '=' -- $parts[2..-1] | string trim -c '"')
        end
    end < $__colorscheme_gum
end

# Zoxide
# Disabling for now b/c `cd src-tauri` would always cd to whitenoise/src-tauri which was infuriating
# zoxide init fish --cmd cd | source

function sesh-sessions
    # TODO: should we emit -t or -c?
    set -l session (sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt '⚡  ')
    if test -n "$session"
        sesh connect $session
    end
end

# Change directory using lf file manager
function cdlf
    set tmp (mktemp)
    lf -last-dir-path=$tmp
    if test -f "$tmp"
        set dir (cat $tmp)
        rm $tmp
        if test -n "$dir" -a -d "$dir"
            cd "$dir"
            commandline -f repaint
        end
    end
end

function fish_user_key_bindings
    bind \es sesh-sessions
    if bind -M insert >/dev/null 2>&1
        bind -M insert \es sesh-sessions
    end
end

# Issue tracking shortcuts
alias i="issues create"
alias inext="issues next"

# Cockpit: auto-attach to Sprite when opening new pane in a claimed tmux window
if set -q TMUX
    set -l __cockpit_sprite (tmux show-option -wqv @cockpit_sprite 2>/dev/null)
    if test -n "$__cockpit_sprite"
        cockpit attach
    end
end
