# shellcheck shell=bash

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
fi

_source="${BASH_SOURCE[0]}"
while [ -L "$_source" ]; do
  _source="$(readlink "$_source")"
done
DOTFILES_DIR="$(cd "$(dirname "$_source")" && pwd)"
export DOTFILES_DIR
unset _source
alias dotfiles_install='$DOTFILES_DIR/install.sh'
alias dotfiles_refresh='git -C $DOTFILES_DIR pull --rebase'

# ── Initialization ────────────────────────────────────────────---

# Initialize Starship prompt.
eval "$(starship init bash)"

if [ "$OS" = "Darwin" ]; then
  # Enable bash completion for Homebrew-installed tools.
  if [ -f "/opt/homebrew/etc/bash_completion" ]; then
    . "/opt/homebrew/etc/bash_completion"
  fi
fi
