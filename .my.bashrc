# shellcheck shell=bash

# Ensure that we initialize terminals exactly once.
[ -n "$_MY_BASHRC_SOURCED" ] && return 0
_MY_BASHRC_SOURCED=1

OS="$(uname -s)"

# ── Env variables ────────────────────────────────────────────

export EDITOR="nano"
export PATH=".:$PATH"

if [ "$OS" = "Darwin" ]; then
    # Disable opening message.
    export BASH_SILENCE_DEPRECATION_WARNING=1
    export PATH="/opt/homebrew/bin:$PATH"
fi

# ── Aliases ────────────────────────────────────────────----------

if [ "$OS" = "Darwin" ]; then
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias grep='grep --color=auto'

    # Strip the Gatekeeper quarantine flag from a CLI so macOS stops blocking it.
    unquarantine() {
        if [ -z "$1" ]; then
            echo "usage: unquarantine <command>" >&2
            return 1
        fi
        local target dir cleared=0
        target="$(command -v "$1")" || {
            echo "unquarantine: '$1' not found in PATH" >&2
            return 1
        }
        while [ -L "$target" ]; do
            dir="$(cd "$(dirname "$target")" && pwd)"
            target="$(readlink "$target")"
            [[ "$target" != /* ]] && target="$dir/$target"
        done
        dir="$(dirname "$target")"
        while IFS= read -r -d '' f; do
            xattr -p com.apple.quarantine "$f" >/dev/null 2>&1 || continue
            xattr -d com.apple.quarantine "$f" && cleared=$((cleared + 1))
        done < <(find "$dir" -print0)
        if [ "$cleared" -eq 0 ]; then
            echo "unquarantine: '$1' had no quarantine flag set"
        else
            echo "unquarantine: cleared quarantine flag from $cleared file(s) under $dir"
        fi
    }
fi

_source="${BASH_SOURCE[0]}"
while [ -L "$_source" ]; do
    _dir="$(cd "$(dirname "$_source")" && pwd)"
    _source="$(readlink "$_source")"
    # Resolve relative symlink targets against the symlink's directory.
    [[ "$_source" != /* ]] && _source="$_dir/$_source"
done
DOTFILES_DIR="$(cd "$(dirname "$_source")" && pwd)"
export DOTFILES_DIR
unset _source _dir
alias dotfiles_go='cd "$DOTFILES_DIR"'
alias dotfiles_install='$DOTFILES_DIR/install.sh'
alias dotfiles_refresh='git -C $DOTFILES_DIR pull --rebase'

alias k='kubectl'
alias kout='kubectl config unset current-context'

alias gs='gh stack'

# ── Paradev ─────────────────────────────────────────────────

if [ -n "$SUPERSET_WORKSPACE_ID" ]; then
    # Show a file in the workspace's editor sidebar. `panes open` resolves a
    # relative path against the workspace root rather than the cwd, so resolve
    # it here instead -- otherwise this opens the wrong file from a subdirectory.
    pv-open() {
        local path
        path="$(realpath "$1")" || return 1
        paradev panes open file "$path" --workspace "$SUPERSET_WORKSPACE_ID"
    }
fi

# ── Initialization ────────────────────────────────────────────---

# Bypass initialization for non-interactive shells.
[[ $- == *i* ]] || return 0

# Initialize Starship prompt.
eval "$(starship init bash)"

if [ "$OS" = "Darwin" ]; then
    # Enable bash completion for Homebrew-installed tools.
    if [ -f "/opt/homebrew/etc/bash_completion" ]; then
        # shellcheck source=/dev/null
        . "/opt/homebrew/etc/bash_completion"
    fi
fi

# Give the `k` alias kubectl's own completion. On macOS the block above already
# preloaded it via bash_completion.d; elsewhere bash-completion lazy-loads by
# command name and never finds it under an alias, so load it by hand.
if command -v kubectl >/dev/null 2>&1; then
    declare -F __start_kubectl >/dev/null || eval "$(kubectl completion bash)"
    eval "$(complete -p kubectl 2>/dev/null | sed 's/kubectl$/k/')"
fi

eval "$(direnv hook bash)"

# Remind at startup if GH_TOKEN isn't configured for Claude — its non-interactive
# shells don't see direnv, so the token must live in ~/.claude/settings.json.
if command -v claude >/dev/null 2>&1; then
    _claude_settings="$HOME/.claude/settings.json"
    if command -v jq >/dev/null 2>&1; then
        _gh_tok="$(jq -r '.env.GH_TOKEN // empty' "$_claude_settings" 2>/dev/null)"
    else
        _gh_tok="$(grep -oE '"GH_TOKEN"[[:space:]]*:[[:space:]]*"[^"]+"' "$_claude_settings" 2>/dev/null)"
    fi
    [ -z "$_gh_tok" ] &&
        printf '\033[33m⚠ GH_TOKEN not set in ~/.claude/settings.json\033[0m — Claude gh/git use the limited platform token.\n' >&2
    unset _claude_settings _gh_tok
fi
