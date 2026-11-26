# shellcheck shell=bash

# Ensure that we initialize terminals exactly once.
[ -n "$_MY_BASHRC_SOURCED" ] && return 0
_MY_BASHRC_SOURCED=1

OS="$(uname -s)"

# ── Env variables ────────────────────────────────────────────

export EDITOR="nano"
export PATH="$PATH:."

if [ "$OS" = "Darwin" ]; then
    # Disable opening message.
    export BASH_SILENCE_DEPRECATION_WARNING=1
    export PATH="/opt/homebrew/bin:$PATH"
    export LANG="en_GB.UTF-8"
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

# Clean up after a stack has merged: stop tracking the stack containing the
# given branch and delete its local branches.
gs-delete() {
    if [ -z "$1" ]; then
        echo "usage: gs-delete <branch>" >&2
        return 1
    fi
    local state stack number branches unsubmitted ids=() id states branch status=0

    # `gh stack unstack` only takes a stack number, so look it up in the local state.
    state="$(git rev-parse --git-common-dir)/gh-stack" || return 1
    if [ ! -f "$state" ]; then
        echo "gs-delete: no gh-stack state in this repository" >&2
        return 1
    fi
    stack="$(jq -c --arg b "$1" \
        '.stacks[] | select(any(.branches[]; .branch == $b))' "$state")" || return 1
    if [ -z "$stack" ]; then
        echo "gs-delete: no stack contains branch '$1'" >&2
        return 1
    fi
    if [[ "$stack" == *$'\n'* ]]; then
        echo "gs-delete: branch '$1' is in several stacks:" \
            "$(jq -rs 'map(.number | tostring) | join(", ")' <<<"$stack")" >&2
        return 1
    fi
    number="$(jq -r '.number' <<<"$stack")"
    branches="$(jq -r '.branches[].branch' <<<"$stack")"

    # Only clean up merged stacks. Ask GitHub: the state's own `merged` flags go stale.
    unsubmitted="$(jq -r '.branches[] | select(.pullRequest.id == null) | .branch' <<<"$stack")"
    if [ -n "$unsubmitted" ]; then
        echo "gs-delete: stack $number has branches without a PR: ${unsubmitted//$'\n'/, }" >&2
        return 1
    fi
    while IFS= read -r id; do
        ids+=(-f "ids[]=$id")
    done < <(jq -r '.branches[].pullRequest.id' <<<"$stack")
    states="$(gh api graphql "${ids[@]}" --jq '[.data.nodes[].state] | unique | join(", ")' \
        -f query='query($ids: [ID!]!) { nodes(ids: $ids) { ... on PullRequest { state } } }')" || return 1
    if [ "$states" != "MERGED" ]; then
        echo "gs-delete: stack $number is not fully merged (PR states: $states)" >&2
        return 1
    fi

    # GitHub refuses to unstack merged PRs, so this only ever acts locally.
    gh stack unstack "$number" --local || return 1
    while IFS= read -r branch; do
        # Some may already be gone; git refuses those checked out in a worktree.
        git show-ref --verify --quiet "refs/heads/$branch" || continue
        git branch -D "$branch" || status=1
    done <<<"$branches"
    return "$status"
}

# ── Paradev ─────────────────────────────────────────────────

if [ -n "$SUPERSET_WORKSPACE_ID" ]; then
    # Show a file in the workspace's editor sidebar. `panes open` resolves a
    # relative path against the workspace root rather than the cwd, so resolve
    # it here instead -- otherwise this opens the wrong file from a subdirectory.
    pv-open() {
        local file root
        file="$(realpath -- "$1")" || return 1
        # Hand Paradev the workspace root spelled the way *it* spells it, otherwise
        # it may choke on casing.
        if [ -n "$SUPERSET_WORKSPACE_PATH" ]; then
            root="$(realpath -- "$SUPERSET_WORKSPACE_PATH")"
            if [ "${file#"$root"/}" != "$file" ]; then
                file="$SUPERSET_WORKSPACE_PATH/${file#"$root"/}"
            fi
        fi
        paradev panes open file "$file" --workspace "$SUPERSET_WORKSPACE_ID" >/dev/null
    }
fi

# ── Initialization ────────────────────────────────────────────---

# Bypass initialization for non-interactive shells.
[[ $- == *i* ]] || return 0

# Initialize Starship prompt.
eval "$(starship init bash)"

# A bare Enter runs no command, so bash keeps $? from the previous one and the
# prompt character stays red. Starship clears its ready flag only when a real
# command runs, so an untouched flag means nothing ran.
_starship_blank_line_status() {
    if [ "${STARSHIP_PREEXEC_READY:-}" = "true" ]; then
        STARSHIP_CMD_STATUS=0
        STARSHIP_PIPE_STATUS=(0)
    fi
}
starship_precmd_user_func="_starship_blank_line_status"

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
