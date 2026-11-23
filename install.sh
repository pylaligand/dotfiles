#!/usr/bin/env sh

set -e

# ── Helpers ──────────────────────────────────────────────────────

has() {
    command -v "$1" >/dev/null 2>&1
}

run() {
    if has sudo; then
        DEBIAN_FRONTEND=noninteractive sudo "$@"
    else
        DEBIAN_FRONTEND=noninteractive "$@"
    fi
}

section() {
    printf "\n%s==> %s%s\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$1" "$(tput sgr0 2>/dev/null || true)"
}

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

# Prevent installing from a git worktree.
if has git; then
    # `worktree list` reports the main worktree first; outside a repo both
    # values come back empty and the check is skipped.
    main_tree="$(git -C "$DOTFILES_DIR" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
    this_tree="$(git -C "$DOTFILES_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$main_tree" ] && [ -n "$this_tree" ] && [ "$main_tree" != "$this_tree" ]; then
        echo "install.sh: refusing to install from a linked worktree." >&2
        echo "  here:            $this_tree" >&2
        echo "  main checkout:   $main_tree" >&2
        echo "  Re-run it from the main checkout." >&2
        exit 1
    fi
fi

# ── CLI tools ────────────────────────────────────────────────────

section "Installing CLI tools"

case "$OS" in
    Darwin)
        if ! has brew; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew bundle --file="$DOTFILES_DIR/Brewfile"
        # Update PATH for further configuration of Homebrew-installed tools.
        export PATH="/opt/homebrew/bin:$PATH"
    ;;
    Linux)
        # Packages available in most distros
        run apt-get update
        run apt-get install -y direnv jq

        # Tools installed via their own installers (not in apt or too old)
        if ! has starship; then
            curl -sSf https://starship.rs/install.sh | sh -s -- -y
        fi
        if ! has yq; then
            curl -sSfLo yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
            chmod +x yq
            run mv yq /usr/local/bin/yq
        fi
        if ! has gh; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | run tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | run tee /etc/apt/sources.list.d/github-cli.list >/dev/null
            run apt-get update
            run apt-get install -y gh
        fi
        # The native installer puts claude in ~/.local/bin.
        export PATH="$HOME/.local/bin:$PATH"
        if ! has claude; then
            curl -fsSL https://claude.ai/install.sh | bash
        fi
    ;;
esac

# ── Persist Claude state across devcontainer rebuilds ─────────────────────────

PERSIST_ROOT=""
if [ "${CODESPACES:-}" = "true" ]; then
    # Codespaces persist all of /workspaces.
    PERSIST_ROOT="/workspaces"
else
    # Local devcontainers only persist /workspaces/<repo>.
    # The repo is the one bind mount under /workspaces; find its mount point, if any.
    REPO_ROOT="$(awk '$5 ~ /^\/workspaces\// {print $5; exit}' /proc/self/mountinfo 2>/dev/null || true)"
    [ -n "$REPO_ROOT" ] && PERSIST_ROOT="$REPO_ROOT/.claude-global"
fi

if [ -n "$PERSIST_ROOT" ]; then
    section "Persisting Claude state -> $PERSIST_ROOT"
    mkdir -p "$PERSIST_ROOT"

    PERSISTENT_CLAUDE_DIR="$PERSIST_ROOT/.claude"
    mkdir -p "$PERSISTENT_CLAUDE_DIR"

    # If $HOME/.claude is a real directory (first migration, or a fresh
    # rebuild where Claude already wrote defaults), merge its contents
    # into the persistent dir without clobbering existing files, then
    # replace it with a symlink.
    if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
        cp -a --update=none "$HOME/.claude/." "$PERSISTENT_CLAUDE_DIR/"
        rm -rf "$HOME/.claude"
        echo "  Migrated \$HOME/.claude -> $PERSISTENT_CLAUDE_DIR"
    fi

    ln -sfn "$PERSISTENT_CLAUDE_DIR" "$HOME/.claude"
    echo "  \$HOME/.claude -> $PERSISTENT_CLAUDE_DIR"

    # Same treatment for ~/.claude.json (MCP list, oauthAccount, trust
    # acknowledgments, onboarding flags). Persistent file wins on rebuild.
    PERSISTENT_CLAUDE_JSON="$PERSIST_ROOT/.claude.json"
    if [ -f "$HOME/.claude.json" ] && [ ! -L "$HOME/.claude.json" ]; then
        if [ ! -e "$PERSISTENT_CLAUDE_JSON" ]; then
            mv "$HOME/.claude.json" "$PERSISTENT_CLAUDE_JSON"
            echo "  Migrated \$HOME/.claude.json -> $PERSISTENT_CLAUDE_JSON"
        else
            rm "$HOME/.claude.json"
        fi
    fi
    [ -e "$PERSISTENT_CLAUDE_JSON" ] || : > "$PERSISTENT_CLAUDE_JSON"
    ln -sf "$PERSISTENT_CLAUDE_JSON" "$HOME/.claude.json"
    echo "  \$HOME/.claude.json -> $PERSISTENT_CLAUDE_JSON"
fi

# ── Symlink dotfiles ─────────────────────────────────────────────

section "Symlinking dotfiles"

for file in .claude/CLAUDE.md .config/git/ignore; do
    mkdir -p "$(dirname "$HOME/$file")"
    ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
    echo "  $file -> $DOTFILES_DIR/$file"
done

# gitconfig uses [include] instead of symlink so `git config --global` works normally
# Remove old symlink from previous bootstrap if present
if [ -L "$HOME/.gitconfig" ]; then
    rm "$HOME/.gitconfig"
fi
if ! grep -q "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig" 2>/dev/null; then
    printf '[include]\n    path = %s/.gitconfig\n' "$DOTFILES_DIR" >> "$HOME/.gitconfig"
    echo "  .gitconfig -> included $DOTFILES_DIR/.gitconfig"
fi

# Starship config (XDG)
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
ln -sf "$DOTFILES_DIR/.config/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
echo "  starship.toml -> $DOTFILES_DIR/.config/starship.toml"

# ── Set default shell ────────────────────────────────────────────

section "Configuring bash"

# Set the default shell on macOS which runs an older version of bash.
if [ "$OS" = "Darwin" ]; then
    BASH_PATH="$(command -v bash)"
    if [ "$SHELL" != "$BASH_PATH" ]; then
        echo "Setting $BASH_PATH as default shell"
        # chsh refuses any shell that is not listed in /etc/shells.
        if ! grep -qxF "$BASH_PATH" /etc/shells 2>/dev/null; then
            echo "$BASH_PATH" | run tee -a /etc/shells >/dev/null
        fi
        # Don't abort the rest of the install if chsh fails.
        run chsh -s "$BASH_PATH" "$USER" ||
            echo "  chsh failed; set the login shell to $BASH_PATH manually." >&2
    fi

    # Terminal.app has its own "Shells open with" preference that overrides the
    # login shell, so chsh alone does not change what it launches.
    TERMINAL_SHELL="$(defaults read com.apple.Terminal Shell 2>/dev/null || true)"
    if [ -n "$TERMINAL_SHELL" ] && [ "$TERMINAL_SHELL" != "$BASH_PATH" ]; then
        echo "  Terminal.app is pinned to $TERMINAL_SHELL, overriding the login shell."
        echo "  Set Terminal > Settings > General > 'Shells open with' to 'Default"
        echo "  login shell', then open a new window."
    fi
fi

if [ "$(readlink "$HOME/.bashrc")" != "$DOTFILES_DIR/.my.bashrc" ]; then
    # -f alone follows a symlink, so appending would write into whatever
    # checkout the link points at. Only append to a real file.
    if [ -f "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
        if ! grep -q "source $DOTFILES_DIR/.my.bashrc" "$HOME/.bashrc"; then
            echo "source $DOTFILES_DIR/.my.bashrc" >> "$HOME/.bashrc"
            echo "  Added include line to .bashrc"
        fi
    else
        # Missing, or a symlink aimed at another checkout: repoint it.
        ln -sfn "$DOTFILES_DIR/.my.bashrc" "$HOME/.bashrc"
        echo "  Linked .bashrc -> $DOTFILES_DIR/.my.bashrc"
    fi
fi

# macOS terminals (Terminal.app, iTerm2) source .bash_profile, not .bashrc.
# Create .bash_profile that sources .bashrc so our config is always loaded.
if [ "$OS" = "Darwin" ] && [ ! -f "$HOME/.bash_profile" ]; then
    cat > "$HOME/.bash_profile" <<'EOF'
# Source .bashrc if it exists (keeps one config for both login and non-login shells)
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
EOF
    echo "  Added .bash_profile"
fi

# -- Claude -------------------------------------------------------

section "Adding Claude plugins"

if ! claude mcp list 2>/dev/null | grep -q "my-linear"; then
    claude mcp add --scope user --transport http my-linear https://mcp.linear.app/mcp
fi
if ! claude mcp list 2>/dev/null | grep -q "my-notion"; then
    claude mcp add --scope user --transport http my-notion https://mcp.notion.com/mcp
fi
if ! claude mcp list 2>/dev/null | grep -q "my-whimsical"; then
    claude mcp add --scope user --transport http my-whimsical https://mcp.whimsical.com/mcp
fi

section "Claude settings"
if has jq; then
    mkdir -p "$HOME/.claude"
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
    tmp_settings="$(mktemp)"
    # Seed an empty GH_TOKEN slot in Claude's user settings so it's a one-field edit
    # (//= leaves an already-filled token untouched on re-runs).
    # cleanupPeriodDays: keep session transcripts ~forever.
    jq '.env.GH_TOKEN //= ""' "$CLAUDE_SETTINGS" \
        | jq '.env.CLAUDE_AFK_TIMEOUT_MS = "1000000"' \
        | jq '.cleanupPeriodDays = 36500' > "$tmp_settings"
    # sh has no pipefail: a failed jq above (e.g. malformed settings.json) leaves
    # tmp empty with exit 0. Abort rather than wipe the settings with it.
    if [ ! -s "$tmp_settings" ]; then
        echo "Failed to update $CLAUDE_SETTINGS; left it unchanged." >&2
        exit 1
    fi
    cat "$tmp_settings" > "$CLAUDE_SETTINGS"
fi

# -- gh CLI -------------------------------------------------------

section "Configuring gh"
if has gh; then
    gh extension install github/gh-stack
fi

section "Done"
echo "Terminal: set GH_TOKEN via a direnv .envrc (e.g. /workspaces/.envrc)."
echo 'Claude:   fill .env.GH_TOKEN in ~/.claude/settings.json.'
echo "Please restart your shell."
