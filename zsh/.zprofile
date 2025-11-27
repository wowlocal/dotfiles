# ============================================================================
# Zsh Profile - Login Shell Configuration
# ============================================================================

# ----------------------------------------------------------------------------
# Homebrew - Hardcoded for speed (saves ~19ms)
# ----------------------------------------------------------------------------
# Run `brew shellenv` manually if paths change
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
fpath[1,0]="/opt/homebrew/share/zsh/site-functions"
eval "$(/usr/bin/env PATH_HELPER_ROOT="/opt/homebrew" /usr/libexec/path_helper -s)"
[ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

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
