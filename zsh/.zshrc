# ============================================================================
# Zsh Configuration - Optimized for Fast Startup
# ============================================================================

# Disable Powerlevel10k gitstatus daemon to prevent background processes (helps Ghostty close confirmation)
typeset -g POWERLEVEL9K_DISABLE_GITSTATUS=1

# ----------------------------------------------------------------------------
# Powerlevel10k Instant Prompt - Must be at the very top
# ----------------------------------------------------------------------------
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Agent terminal status integration (provided by agterm when installed).
[[ -f "$HOME/.config/agterm/agent-status/shell/integration.sh" ]] && source "$HOME/.config/agterm/agent-status/shell/integration.sh"

# ----------------------------------------------------------------------------
# Environment Variables
# ----------------------------------------------------------------------------
export EDITOR='nvim'
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/.lmstudio/bin"
export PATH="$PATH:/Applications/IntelliJ IDEA CE.app/Contents/MacOS"

# Remote SSH sessions such as Termius do not inherit macOS launchd's agent socket.
# Reconnect to the existing agent without overriding an agent forwarded by the client.
if [[ -z "${SSH_AUTH_SOCK:-}" && "$OSTYPE" == darwin* ]]; then
  SSH_AUTH_SOCK="$(
    launchctl print "gui/$(id -u)/com.openssh.ssh-agent" 2>/dev/null |
      awk '/SSH_AUTH_SOCK =>/ {print $3; exit}'
  )"

  if [[ -S "$SSH_AUTH_SOCK" ]]; then
    export SSH_AUTH_SOCK
  else
    unset SSH_AUTH_SOCK
  fi
fi

# Cache brew prefix to avoid subprocess spawns (saves ~30-50ms per call)
HOMEBREW_PREFIX="$(brew --prefix)"

# Ensure interactive shells load the default keymap so history keys work in all terminals
if [[ $- == *i* ]]; then
  bindkey -e
fi

# Make Ctrl+W delete words by path components (stop at /, ., -)
# Remove these characters from WORDCHARS so they act as word boundaries
WORDCHARS='*?_[]~=&;!#$%^(){}<>'

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

# Keep giant / multi-line commands out of the saved history file so they don't
# clutter autosuggestions. Such commands still run and stay reachable via
# up-arrow in the current session; they're just never written to $HISTFILE.
HIST_MAX_CMD_LEN=300             # don't save single commands longer than this
autoload -Uz add-zsh-hook
_hist_skip_giant() {
  emulate -L zsh
  local line=${1%%$'\n'}         # strip the trailing newline zsh appends
  [[ $line == *$'\n'* ]] && return 1               # multi-line -> don't save
  (( ${#line} > HIST_MAX_CMD_LEN )) && return 1    # too long  -> don't save
  return 0
}
add-zsh-hook zshaddhistory _hist_skip_giant

# ----------------------------------------------------------------------------
# Prompt - Powerlevel10k (replaces minimal prompt)
# ----------------------------------------------------------------------------
# Previous minimal prompt is commented out - using Powerlevel10k instead
# setopt PROMPT_SUBST
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%~%f
# %F{red}❯%f '

# Keep cursor as a steady block (DECSCUSR Ps=2)
precmd() {
  printf '\e[2 q'
}

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

# Keep the fnm-selected Node ahead of ~/.local/bin's system Node.
if command -v fnm >/dev/null; then
  eval "$(fnm env --use-on-cd)"
fi

# ----------------------------------------------------------------------------
# Aliases
# ----------------------------------------------------------------------------
alias tm='task-master'
alias taskmaster='task-master'
alias ghsty='open . -a Ghostty'

# ----------------------------------------------------------------------------
# Additional Config Files
# ----------------------------------------------------------------------------
# Load visual enhancements last (syntax highlighting must be at the end)
for config in ~/.config/zsh/*.zsh; do
  [ -f "$config" ] && source "$config"
done

# Note: zsh-syntax-highlighting is loaded in visual-enhancements.zsh
# and MUST be sourced last for optimal performance

# ----------------------------------------------------------------------------
# Powerlevel10k Theme
# ----------------------------------------------------------------------------
source ~/dotfiles/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
