# ============================================================================
# Zsh Configuration - Optimized for Fast Startup
# ============================================================================

# ----------------------------------------------------------------------------
# Environment Variables
# ----------------------------------------------------------------------------
export EDITOR='nvim'
export PATH="$PATH:/Users/mike/.lmstudio/bin"
export PATH="$PATH:/Applications/IntelliJ IDEA CE.app/Contents/MacOS"

# ----------------------------------------------------------------------------
# Prompt - Minimal Robbyrussell-style (replaces oh-my-zsh)
# ----------------------------------------------------------------------------
autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%F{cyan}(%b)%f '
zstyle ':vcs_info:*' enable git

setopt PROMPT_SUBST
PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%~%f ${vcs_info_msg_0_}%F{red}❯%f '

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
