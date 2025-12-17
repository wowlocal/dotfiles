# ----------------------------------------------------------------------------
# FNM - Fast Node Manager (lazy-loaded)
# ----------------------------------------------------------------------------
# Placed in .zshenv so it works for both interactive and non-interactive shells
if command -v fnm >/dev/null; then
  _fnm_lazy_load() {
    unfunction node npm npx fnm nvm 2>/dev/null
    eval "$(command fnm env --use-on-cd)"
  }

  _fnm_exec() {
    (( $+functions[_fnm_lazy_load] )) && _fnm_lazy_load
    command "$@"
  }

  fnm() { _fnm_exec fnm "$@"; }
  node() { _fnm_exec node "$@"; }
  npm() { _fnm_exec npm "$@"; }
  npx() { _fnm_exec npx "$@"; }
  nvm() { _fnm_exec fnm "$@"; }
fi
