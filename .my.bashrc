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

alias kout='kubectl config unset current-context'

# ── Initialization ────────────────────────────────────────────---

# Initialize Starship prompt.
eval "$(starship init bash)"

if [ "$OS" = "Darwin" ]; then
  # Enable bash completion for Homebrew-installed tools.
  if [ -f "/opt/homebrew/etc/bash_completion" ]; then
    # shellcheck source=/dev/null
    . "/opt/homebrew/etc/bash_completion"
  fi
fi

eval "$(direnv hook bash)"
