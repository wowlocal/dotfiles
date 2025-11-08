# ============================================================================
# Zsh Profile - Login Shell Configuration
# ============================================================================

# ----------------------------------------------------------------------------
# Homebrew
# ----------------------------------------------------------------------------
eval "$(/opt/homebrew/bin/brew shellenv)"

# ----------------------------------------------------------------------------
# Cargo (Rust)
# ----------------------------------------------------------------------------
export PATH="$HOME/.cargo/bin:$PATH"

# ----------------------------------------------------------------------------
# Pyenv - Lazy Loading (saves ~80ms)
# ----------------------------------------------------------------------------
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Only do path init, defer full init
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init --path)"

  # Lazy load full pyenv initialization
  pyenv() {
    unset -f pyenv
    eval "$(command pyenv init - zsh)"
    pyenv "$@"
  }
fi

# ----------------------------------------------------------------------------
# OrbStack
# ----------------------------------------------------------------------------
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
