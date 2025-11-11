# ============================================================================
# Alternative Prompt Styles for Long Paths
# ============================================================================
# Uncomment the PROMPT line you prefer and reload your shell with: source ~/.zshrc

# ----------------------------------------------------------------------------
# STYLE 1: Two-line with 40-char truncation (CURRENT - RECOMMENDED)
# ----------------------------------------------------------------------------
# Good for: Long paths, keeps input line clean
# Example:
# ✓ mike@Mishas-MacBook-Pro-2 .../@studio/typescript-spec/v0-xml-to-json-conversion (serve-widget-meta-py)
# ❯ your-command-here
#
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%40<...<%~%<<%f ${vcs_info_msg_0_}
# %F{red}❯%f '

# ----------------------------------------------------------------------------
# STYLE 2: Two-line with last 3 directories only
# ----------------------------------------------------------------------------
# Good for: Focusing on current location, clean look
# Example:
# ✓ mike@Mishas-MacBook-Pro-2 typescript-spec/v0-xml-to-json-conversion (serve-widget-meta-py)
# ❯ your-command-here
#
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%3~%f ${vcs_info_msg_0_}
# %F{red}❯%f '

# ----------------------------------------------------------------------------
# STYLE 3: Compact single-line with last 2 directories
# ----------------------------------------------------------------------------
# Good for: Minimalists, short paths
# Example: ✓ mike@Mishas-MacBook-Pro-2 v0-xml-to-json-conversion (serve-widget-meta-py) ❯
#
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%2~%f ${vcs_info_msg_0_}%F{red}❯%f '

# ----------------------------------------------------------------------------
# STYLE 4: Minimal two-line (path only, no username/host)
# ----------------------------------------------------------------------------
# Good for: Single-user systems, maximum space for path
# Example:
# ✓ ~/Developer/@ai/@genui/@studio/typescript-spec/v0-xml-to-json-conversion (serve-widget-meta-py)
# ❯ your-command-here
#
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%~%f ${vcs_info_msg_0_}
# %F{red}❯%f '

# ----------------------------------------------------------------------------
# STYLE 5: Minimal two-line with smart truncation (60 chars)
# ----------------------------------------------------------------------------
# Good for: Balance between context and space
# Example:
# ✓ .../@ai/@genui/@studio/typescript-spec/v0-xml-to-json-conversion (serve-widget-meta-py)
# ❯ your-command-here
#
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%60<...<%~%<<%f ${vcs_info_msg_0_}
# %F{red}❯%f '

# ----------------------------------------------------------------------------
# STYLE 6: Ultra-compact with basename only + git
# ----------------------------------------------------------------------------
# Good for: When you know where you are, want clean terminal
# Example: ✓ v0-xml-to-json-conversion (serve-widget-meta-py) ❯
#
# PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%1~%f ${vcs_info_msg_0_}%F{red}❯%f '
