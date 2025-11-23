# ============================================================================
# Zsh Configuration - Optimized for Fast Startup
# ============================================================================

# ----------------------------------------------------------------------------
# Environment Variables
# ----------------------------------------------------------------------------
export EDITOR='nvim'
export PATH="$PATH:/Users/mike/.lmstudio/bin"
export PATH="$PATH:/Applications/IntelliJ IDEA CE.app/Contents/MacOS"

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
# Prompt - Minimal Robbyrussell-style (replaces oh-my-zsh)
# ----------------------------------------------------------------------------
autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%F{cyan}(%b)%f '
zstyle ':vcs_info:*' enable git

setopt PROMPT_SUBST

# Truncate long paths intelligently
# %2~ shows last 2 directories, %3~ shows last 3, etc.
# Or use %40<...<%~%<< to truncate at 40 chars with ellipsis
# Multi-line prompt for better readability with long paths
PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%40<...<%~%<<%f ${vcs_info_msg_0_}
%F{red}❯%f '

# ----------------------------------------------------------------------------
# FNM - Fast Node Manager (replaces NVM, saves ~250ms)
# ----------------------------------------------------------------------------
eval "$(fnm env --use-on-cd)"

# Alias nvm to fnm for muscle memory
alias nvm='fnm'

# ----------------------------------------------------------------------------
# Completion System - Optimized (saves ~100ms)
# ----------------------------------------------------------------------------
fpath=(~/.docker/completions $fpath)
autoload -Uz compinit

# Only regenerate compdump once a day
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

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
if [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Try - experiment with commands before committing
if [[ -f "$HOME/.local/try.rb" ]]; then
  eval "$(ruby ~/.local/try.rb init ~/src/tries)"
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
