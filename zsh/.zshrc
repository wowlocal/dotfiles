# ============================================================================
# Zsh Configuration - Optimized for Fast Startup
# ============================================================================

# ----------------------------------------------------------------------------
# Environment Variables
# ----------------------------------------------------------------------------
export EDITOR='nvim'
export PATH="$PATH:/Users/mike/.lmstudio/bin"
export PATH="$PATH:/Applications/IntelliJ IDEA CE.app/Contents/MacOS"

# Cache brew prefix to avoid subprocess spawns (saves ~30-50ms per call)
HOMEBREW_PREFIX="$(brew --prefix)"

# Ensure interactive shells load the default keymap so history keys work in all terminals
if [[ $- == *i* ]]; then
  bindkey -e
fi

# ----------------------------------------------------------------------------
# History Configuration
# ----------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# History options
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits
setopt SHARE_HISTORY             # Share history between all sessions
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file
setopt HIST_VERIFY               # Do not execute immediately upon history expansion

# ----------------------------------------------------------------------------
# Prompt - Minimal and Fast
# ----------------------------------------------------------------------------
setopt PROMPT_SUBST

# Multi-line prompt for better readability with long paths
PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%40<...<%~%<<%f
%F{red}❯%f '

# Keep cursor as a steady block (DECSCUSR Ps=2)
precmd() {
  printf '\e[2 q'
}

# ----------------------------------------------------------------------------
# FNM - Fast Node Manager (lazy-loaded)
# ----------------------------------------------------------------------------
# Lazy-load fnm - only initialize when node/npm/npx/fnm is actually used
_fnm_lazy_load() {
  unfunction node npm npx fnm nvm 2>/dev/null
  eval "$(command fnm env --use-on-cd)"
}

fnm() { _fnm_lazy_load; fnm "$@"; }
node() { _fnm_lazy_load; node "$@"; }
npm() { _fnm_lazy_load; npm "$@"; }
npx() { _fnm_lazy_load; npx "$@"; }
nvm() { _fnm_lazy_load; fnm "$@"; }

# ----------------------------------------------------------------------------
# Completion System - Optimized (saves ~100ms)
# ----------------------------------------------------------------------------
fpath=(~/.docker/completions $fpath)
autoload -Uz compinit

# Only regenerate compdump once per day using date-based check
# Use -C flag to skip security checks (safe for personal machines)
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
  compinit
else
  compinit -C
fi

# Compile zcompdump in background for faster loading next time
{
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
    zcompile "$zcompdump"
  fi
} &!

# Completion navigation
bindkey '^[[Z' reverse-menu-complete  # Shift-Tab to go backwards in menu

# ----------------------------------------------------------------------------
# Shell Integrations
# ----------------------------------------------------------------------------

# FZF
[ -f "$HOME/.fzf" ] && source "$HOME/.fzf"

# Zoxide
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# Zsh Autosuggestions
if [ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Try - experiment with commands before committing (lazy-loaded)
if [[ -f "$HOME/.local/try.rb" ]]; then
  try() {
    # Remove this wrapper function
    unfunction try
    # Load the real try function
    eval "$(ruby ~/.local/try.rb init ~/src/tries)"
    # Call it with the original arguments
    try "$@"
  }
fi

# Local environment
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# ----------------------------------------------------------------------------
# Aliases
# ----------------------------------------------------------------------------
alias tm='task-master'
alias taskmaster='task-master'
alias gh='open . -a Ghostty'

# ----------------------------------------------------------------------------
# Additional Config Files
# ----------------------------------------------------------------------------
# Load visual enhancements last (syntax highlighting must be at the end)
for config in ~/.config/zsh/*.zsh; do
  [ -f "$config" ] && source "$config"
done

# Note: zsh-syntax-highlighting is loaded in visual-enhancements.zsh
# and MUST be sourced last for optimal performance
