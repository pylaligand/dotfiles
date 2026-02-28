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

# ── Install zsh ──────────────────────────────────────────────────
if ! has zsh; then
    section "Installing zsh"
    case "$OS" in
        Darwin) brew install zsh ;;
        Linux) run apt-get update && run apt-get install -o Dpkg::Options::="--force-confnew" -y zsh ;;
    esac
fi

# ── Remove Oh My Zsh ────────────────────────────────────────────
if [ -d "$HOME/.oh-my-zsh" ]; then
    section "Removing Oh My Zsh"
    rm -rf "$HOME/.oh-my-zsh"
fi

# ── CLI tools ────────────────────────────────────────────────────
section "Installing CLI tools"
case "$OS" in
    Darwin)
        if ! has brew; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew bundle --file="$DOTFILES_DIR/Brewfile"
    ;;
    Linux)
        # Packages available in most distros
        run apt-get update
        run apt-get install -y fzf ripgrep fd-find bat jq direnv

        # Symlink fd/bat if installed under alternate names (Debian/Ubuntu)
        if [ ! -e "$HOME/.local/bin/fd" ] && has fdfind; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        fi
        if [ ! -e "$HOME/.local/bin/bat" ] && has batcat; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
        fi

        # Neovim (apt version is usually outdated)
        if ! has nvim; then
            curl -sSfLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
            run tar -C /usr/local --strip-components=1 -xzf nvim-linux-x86_64.tar.gz
            rm -f nvim-linux-x86_64.tar.gz
        fi

        # Tools installed via their own installers (not in apt or too old)
        if ! has starship; then
            curl -sSf https://starship.rs/install.sh | sh -s -- -y
        fi
        if ! has zoxide; then
            curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
        fi
        if ! has eza; then
            cargo install eza 2>/dev/null || echo "Skipping eza (no cargo)"
        fi
        if ! has delta; then
            cargo install git-delta 2>/dev/null || echo "Skipping delta (no cargo)"
        fi
        if ! has gh; then
            curl -sSfL https://cli.github.com/packages/githubcli-archive-keyring.gpg | run tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | run tee /etc/apt/sources.list.d/github-cli.list >/dev/null
            run apt-get update && run apt-get install -y gh
        fi
        if ! has lazygit; then
            LAZYGIT_VERSION=$(curl -sSf "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
            curl -sSfLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            run tar -C /usr/local/bin -xzf lazygit.tar.gz lazygit
            rm -f lazygit.tar.gz
        fi
        if ! has yq; then
            curl -sSfLo yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
            chmod +x yq
            run mv yq /usr/local/bin/yq
        fi
    ;;
esac

# ── Zsh plugins ──────────────────────────────────────────────────
section "Installing zsh plugins"
ZSH_PLUGINS="$HOME/.zsh/plugins"
mkdir -p "$ZSH_PLUGINS"

clone_or_pull() {
    repo="$1"
    dest="$ZSH_PLUGINS/$(basename "$repo")"
    if [ -d "$dest" ]; then
        git -C "$dest" fetch --depth 1 --quiet
        git -C "$dest" reset --hard --quiet origin/HEAD
    else
        git clone --depth 1 "https://github.com/$repo.git" "$dest"
    fi
}

clone_or_pull "zdharma-continuum/fast-syntax-highlighting"
clone_or_pull "zsh-users/zsh-autosuggestions"
clone_or_pull "zsh-users/zsh-completions"

# ── Symlink dotfiles ─────────────────────────────────────────────
section "Symlinking dotfiles"
for file in .zshrc .gitignore_global .editorconfig; do
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

# Symlink directories
ln -sfn "$DOTFILES_DIR/zsh_functions" "$HOME/.zsh_functions"
echo "  .zsh_functions -> $DOTFILES_DIR/zsh_functions"

# Starship config (XDG)
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
ln -sf "$DOTFILES_DIR/.config/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
echo "  starship.toml -> $DOTFILES_DIR/.config/starship.toml"

# ── Neovim (LazyVim) ─────────────────────────────────────────────
if has nvim && [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" ]; then
    section "Installing LazyVim"
    git clone https://github.com/LazyVim/starter "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    # Remove starter's .git so it doesn't conflict with your own customizations
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/.git"
fi

# ── Set default shell ────────────────────────────────────────────
if [ "$(basename "$SHELL")" != "zsh" ]; then
    section "Setting zsh as default shell"
    run chsh -s "$(command -v zsh)" "$USER"
fi

section "Done"
echo "Restart your shell or run: exec zsh"
