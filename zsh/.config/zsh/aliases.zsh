# ============================================================================
# Additional Aliases and Functions
# ============================================================================
# This file is automatically sourced by .zshrc
# Add your custom aliases, functions, and configurations here

# Example aliases (customize as needed)
# alias ls='ls -G'
# alias ll='ls -lah'
# alias grep='grep --color=auto'

# Display images in Ghostty using the Kitty graphics protocol.
alias imgcat='ghostty-imgcat'

# Tail output when opening files with less
lg() {
  less +G "$@"
}

# Upload local files and folders dropped into an interactive tail-mini SSH
# session, then paste their remote paths at the current cursor position.
# All other SSH invocations continue to use OpenSSH directly.
ssh() {
  local ssh_bin=/usr/bin/ssh

  if (( $# == 1 )) && [[ $1 == tail-mini && -t 0 && -t 1 ]]; then
    local helper="$HOME/.local/bin/ssh-dragdrop.py"
    if [[ -r $helper ]] && command -v python3 >/dev/null 2>&1; then
      command python3 "$helper" \
        --host tail-mini \
        --remote-dir /Users/michael/.ssh-dragdrop-uploads \
        --ssh-bin "$ssh_bin" \
        -- "$ssh_bin" tail-mini
      return $?
    fi

    print -u2 -- "ssh drag & drop helper is unavailable; connecting normally."
  fi

  command "$ssh_bin" "$@"
}
