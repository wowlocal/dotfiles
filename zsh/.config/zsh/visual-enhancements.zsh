# ============================================================================
# Visual Enhancements - Better Shell Experience
# ============================================================================

# ----------------------------------------------------------------------------
# LS Colors - Enable colors for ls command
# ----------------------------------------------------------------------------
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# ----------------------------------------------------------------------------
# EZA - Modern replacement for ls with better colors and icons
# ----------------------------------------------------------------------------
if command -v eza &> /dev/null; then
  alias ls='eza --color=auto --icons=auto --sort=type --group-directories-first'
  alias ll='eza -lah --color=auto --icons=auto --sort=type --group-directories-first --git'
  alias la='eza -a --color=auto --icons=auto --sort=type --group-directories-first'
  alias l='eza -lh --color=auto --icons=auto --sort=type --group-directories-first --git'
  alias lt='eza --tree --level=2 --color=auto --icons=auto --sort=type --group-directories-first'
  alias llt='eza -lah --tree --level=2 --color=auto --icons=auto --sort=type --group-directories-first --git'
elif command -v gls &> /dev/null; then
  # Prefer GNU ls when available so directories are grouped first
  alias ls='gls --color=auto --group-directories-first'
  alias ll='gls -lah --color=auto --group-directories-first'
  alias la='gls -A --color=auto --group-directories-first'
  alias l='gls -lh --color=auto --group-directories-first'
else
  # Fallback to standard ls with colors
  alias ls='ls -G'
  alias ll='ls -lah'
  alias la='ls -A'
  alias l='ls -lh'
fi

# ----------------------------------------------------------------------------
# BAT - Better cat with syntax highlighting
# ----------------------------------------------------------------------------
if command -v bat &> /dev/null; then
  # Use 'bcat' for bat with pager if you want syntax highlighting
  alias bcat='bat --paging=never'
  export BAT_THEME="Monokai Extended"
  export BAT_STYLE="numbers,changes,header"
fi

# ----------------------------------------------------------------------------
# GREP - Colorize grep output
# ----------------------------------------------------------------------------
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ----------------------------------------------------------------------------
# DIFFT - Better diff with syntax highlighting
# ----------------------------------------------------------------------------
if command -v difft &> /dev/null; then
  alias diff='difft'
fi

# ----------------------------------------------------------------------------
# FZF - Better fuzzy finder with preview
# ----------------------------------------------------------------------------
if command -v fzf &> /dev/null; then
  # Use fd instead of find if available
  if command -v fd &> /dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  # Better colors and preview
  export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border
    --inline-info
    --color=fg:#d0d0d0,bg:#121212,hl:#5f87af
    --color=fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff
    --color=info:#afaf87,prompt:#d7005f,pointer:#af5fff
    --color=marker:#87ff00,spinner:#af5fff,header:#87afaf
  "

  # Preview files with bat or cat
  if command -v bat &> /dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  else
    export FZF_CTRL_T_OPTS="--preview 'cat {}'"
  fi

  # Preview directories with eza or ls
  if command -v eza &> /dev/null; then
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {}'"
  else
    export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
  fi
fi

# ----------------------------------------------------------------------------
# Completion Menu Colors
# ----------------------------------------------------------------------------
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

# ----------------------------------------------------------------------------
# Zsh Syntax Highlighting (must be at the end)
# ----------------------------------------------------------------------------
if [ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

  # Customize highlighting colors
  ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=cyan,bold'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=blue,bold'
  ZSH_HIGHLIGHT_STYLES[function]='fg=magenta,bold'
  ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
  ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=cyan,bold'
  ZSH_HIGHLIGHT_STYLES[globbing]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'
  ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=magenta'
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=magenta'
fi
