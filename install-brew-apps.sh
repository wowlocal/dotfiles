#!/usr/bin/env bash
# ============================================================================
# Homebrew Installation Script
# ============================================================================
# Installs essential Homebrew packages required by dotfiles configuration
#
# Usage:
#   ./install-brew-apps.sh [--minimal]
#
# Options:
#   --minimal    Install only core required packages (skip optional tools)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
MINIMAL=false
if [[ "$1" == "--minimal" ]]; then
  MINIMAL=true
fi

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
  echo -e "\n${BLUE}==>${NC} ${1}"
}

print_success() {
  echo -e "${GREEN}✓${NC} ${1}"
}

print_warning() {
  echo -e "${YELLOW}!${NC} ${1}"
}

print_error() {
  echo -e "${RED}✗${NC} ${1}"
}

check_command() {
  if command -v "$1" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# ============================================================================
# Check Prerequisites
# ============================================================================

print_header "Checking prerequisites..."

# Check if Homebrew is installed
if ! check_command brew; then
  print_error "Homebrew is not installed!"
  echo "Install it from: https://brew.sh/"
  echo "Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

print_success "Homebrew is installed"

# ============================================================================
# Core Required Packages
# ============================================================================

print_header "Installing core required packages..."

CORE_PACKAGES=(
  "stow"                    # Symlink manager for dotfiles
  "fnm"                     # Fast Node Manager (required by .zshrc)
  "zsh-autosuggestions"     # Fish-like autosuggestions (required by .zshrc)
  "zsh-syntax-highlighting" # Syntax highlighting (required by visual-enhancements.zsh)
)

for package in "${CORE_PACKAGES[@]}"; do
  if brew list "$package" &> /dev/null; then
    print_warning "$package is already installed"
  else
    echo "Installing $package..."
    brew install "$package"
    print_success "Installed $package"
  fi
done

# ============================================================================
# Visual Enhancement Packages
# ============================================================================

print_header "Installing visual enhancement packages..."

VISUAL_PACKAGES=(
  "eza"        # Modern ls replacement with icons
  "bat"        # Better cat with syntax highlighting
  "git-delta"  # Beautiful git diffs
  "fzf"        # Fuzzy finder
  "fd"         # Fast alternative to find (used by fzf)
)

for package in "${VISUAL_PACKAGES[@]}"; do
  if brew list "$package" &> /dev/null; then
    print_warning "$package is already installed"
  else
    echo "Installing $package..."
    brew install "$package"
    print_success "Installed $package"
  fi
done

# Install fzf shell integrations
if check_command fzf && [[ ! -f "$HOME/.fzf.zsh" ]]; then
  print_header "Setting up fzf shell integrations..."
  "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
  print_success "fzf integrations installed"
fi

# ============================================================================
# Optional Productivity Tools (skip with --minimal)
# ============================================================================

if [[ "$MINIMAL" == false ]]; then
  print_header "Installing optional productivity tools..."

  OPTIONAL_PACKAGES=(
    "zoxide"   # Smarter cd command
    "ripgrep"  # Fast grep alternative
    "htop"     # Better top
    "tree"     # Directory tree viewer
    "jq"       # JSON processor
    "tldr"     # Simplified man pages
  )

  # Install try (manual installation - brew formula has checksum issues)
  print_header "Installing try (experiment with commands)..."
  if [[ -f "$HOME/.local/bin/try" ]]; then
    print_warning "try is already installed"
  else
    echo "Installing try manually..."
    mkdir -p "$HOME/.local/bin"
    curl -sL https://raw.githubusercontent.com/tobi/try/refs/heads/main/try.rb -o "$HOME/.local/bin/try"
    chmod +x "$HOME/.local/bin/try"
    print_success "Installed try to ~/.local/bin/try"
  fi

  for package in "${OPTIONAL_PACKAGES[@]}"; do
    if brew list "$package" &> /dev/null; then
      print_warning "$package is already installed"
    else
      echo "Installing $package..."
      brew install "$package"
      print_success "Installed $package"
    fi
  done
else
  print_warning "Skipping optional packages (--minimal mode)"
fi

# ============================================================================
# Configure Git Delta
# ============================================================================

print_header "Configuring git-delta..."

if check_command delta; then
  # Check if delta is already configured
  if git config --global --get core.pager &> /dev/null; then
    print_warning "Git pager already configured, skipping delta setup"
  else
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate "true"
    git config --global delta.light "false"
    git config --global delta.side-by-side "true"
    git config --global merge.conflictstyle "diff3"
    git config --global diff.colorMoved "default"
    print_success "Git delta configured"
  fi
fi

# ============================================================================
# Summary
# ============================================================================

print_header "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Deploy dotfiles: cd ~/dotfiles && stow zsh"
echo "  2. Restart your shell: exec zsh"
echo "  3. Check VISUAL_ENHANCEMENTS.md for feature overview"
echo ""
print_success "All done!"
