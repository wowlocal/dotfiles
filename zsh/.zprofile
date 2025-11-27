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
# Pyenv - Fully Lazy Loaded (saves ~87ms)
# ----------------------------------------------------------------------------
export PYENV_ROOT="$HOME/.pyenv"

# Set paths manually instead of calling pyenv init --path (saves 87ms)
if [[ -d $PYENV_ROOT ]]; then
  export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

  # Lazy load pyenv - only initialize when python/pip/pyenv is actually used
  _pyenv_lazy_load() {
    unfunction pyenv python pip 2>/dev/null
    eval "$(pyenv init - --no-rehash zsh)"
  }

  pyenv() { _pyenv_lazy_load; pyenv "$@"; }
  python() { _pyenv_lazy_load; python "$@"; }
  pip() { _pyenv_lazy_load; pip "$@"; }
fi

# ----------------------------------------------------------------------------
# OrbStack
# ----------------------------------------------------------------------------
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
