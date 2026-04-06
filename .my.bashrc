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

if [ "${CODESPACES-}" = "true" ]; then
  alias refresh_dotfiles="git -C /workspaces/.codespaces/.persistedshare/dotfiles pull --rebase"
fi

# ── Initialization ────────────────────────────────────────────---

# Initialize Starship prompt.
eval "$(starship init bash)"

if [ "$OS" = "Darwin" ]; then
  # Enable bash completion for Homebrew-installed tools.
  if [ -f "/opt/homebrew/etc/bash_completion" ]; then
    . "/opt/homebrew/etc/bash_completion"
  fi
fi
