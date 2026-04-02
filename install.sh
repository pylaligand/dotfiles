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
        run apt-get install -y jq

        # Tools installed via their own installers (not in apt or too old)
        if ! has starship; then
            curl -sSf https://starship.rs/install.sh | sh -s -- -y
        fi
        if ! has yq; then
            curl -sSfLo yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
            chmod +x yq
            run mv yq /usr/local/bin/yq
        fi
        if ! has claude; then
            curl -fsSL https://claude.ai/install.sh | bash
        fi
    ;;
esac

# ── Symlink dotfiles ─────────────────────────────────────────────

section "Symlinking dotfiles"

for file in .claude/CLAUDE.md .my.gitignore; do
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
    printf '[include]\n    path = %s/.gitconfig\n' "$DOTFILES_DIR" >>"$HOME/.gitconfig"
    echo "  .gitconfig -> included $DOTFILES_DIR/.gitconfig"
fi

# Starship config (XDG)
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
ln -sf "$DOTFILES_DIR/.config/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
echo "  starship.toml -> $DOTFILES_DIR/.config/starship.toml"

# ── Set default shell ────────────────────────────────────────────

section "Configuring bash"

if [ "$(basename "$SHELL")" != "bash" ]; then
    echo "Setting bash as default shell"
    run chsh -s "$(command -v bash)" "$USER"
fi

if [ "$(readlink "$HOME/.bashrc")" != "$DOTFILES_DIR/.my.bashrc" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "source $DOTFILES_DIR/.my.bashrc" "$HOME/.bashrc"; then
            echo "source $DOTFILES_DIR/.my.bashrc" >> "$HOME/.bashrc"
            echo "  Added include line to .bashrc"
        fi
    else
        ln -sf "$DOTFILES_DIR/.my.bashrc" "$HOME/.bashrc"
        echo "  Added .bashrc"
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

section "Configuring Claude"

if ! claude mcp list 2>/dev/null | grep -q "my-linear"; then
    claude mcp add --scope user --transport http my-linear https://mcp.linear.app/mcp
fi
if ! claude mcp list 2>/dev/null | grep -q "my-notion"; then
    claude mcp add --scope user --transport http my-notion https://mcp.notion.com/mcp
fi
if ! claude mcp list 2>/dev/null | grep -q "my-github"; then
    claude mcp add --scope user --transport http my-github https://api.githubcopilot.com/mcp
fi

section "Done"
echo "Please restart your shell."
