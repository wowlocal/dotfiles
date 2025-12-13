# Dotfiles

My personal dotfiles managed with GNU Stow.

## Features

- **Fast zsh startup** (~50-80ms vs ~330ms) through lazy-loading
- **Modular configuration** - organized by application
- **Git version control** - track changes and sync across machines
- **Easy deployment** - one command to set up on new machines

## Installation

The Powerlevel10k prompt theme is tracked as a git submodule. Clone with `--recurse-submodules` or run `git submodule update --init --recursive` after cloning/pulling so the theme files are available locally.

### Quick Start (Recommended)

```bash
# Clone this repo (or initialize if already created)
cd ~/dotfiles
git submodule update --init --recursive  # Fetch powerlevel10k prompt theme

# Install all required Homebrew packages
./install-brew-apps.sh

# Deploy zsh configuration
stow zsh

# Restart your shell
exec zsh
```

### Manual Installation

If you prefer to install packages manually:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install core packages
brew install stow fnm zsh-autosuggestions zsh-syntax-highlighting

# Install visual enhancement packages
brew install eza bat git-delta fzf fd

# Install optional productivity tools
brew install zoxide ripgrep htop tree jq tldr difftastic

# Deploy dotfiles
cd ~/dotfiles
git submodule update --init --recursive  # Ensure powerlevel10k is present
stow zsh

# Restart your shell
exec zsh
```

### Installation Script Options

```bash
./install-brew-apps.sh          # Install all packages (recommended)
./install-brew-apps.sh --minimal # Install only core required packages
```

### Remove/Unstow

```bash
cd ~/dotfiles
stow -D zsh  # Removes symlinks
```

## Structure

```
dotfiles/
├── ghostty/                # Ghostty terminal config
├── git/                    # Git config
├── keybindings/            # macOS keybindings
├── lazygit/                # LazyGit config
├── lf/                     # lf file manager config
├── powerlevel10k/          # Prompt theme (submodule)
├── xcode/                  # Xcode keybindings & themes
├── zed/                    # Zed editor settings
├── zsh/                    # Zsh shell config
│   ├── .zshrc
│   ├── .zprofile
│   └── .config/zsh/
└── README.md
```

## Optimizations

- **NVM lazy-loading**: Loads only when node/npm/nvm commands are used
- **Pyenv lazy-loading**: Defers full initialization until needed
- **Completion caching**: Regenerates only once per day
- **Minimal prompt**: Custom prompt replacing oh-my-zsh (207ms saved)

## LazyGit

Stow the LazyGit config (sets [difftastic](https://difftastic.wilfred.me.uk/) as the default diff viewer with delta as a fallback pager you can cycle to with `|`):

```bash
stow lazygit
```

## Ghostty

Stow the Ghostty terminal config:

```bash
stow ghostty
```

## Zed

Stow the Zed editor settings (settings + keymap):

```bash
stow zed
```

## KeyBindings

Stow macOS keybindings for Cocoa apps:

```bash
stow keybindings
```

Restart apps to apply changes. Only works with native macOS apps (not Electron).

## Xcode

Stow Xcode keybindings and color themes:

```bash
stow xcode
```

## Adding New Configurations

1. Create a new directory for the application:
   ```bash
   mkdir -p ~/dotfiles/nvim/.config/nvim
   ```

2. Add your config files following the home directory structure

3. Stow it:
   ```bash
   stow nvim
   ```

## Updating

```bash
cd ~/dotfiles
git submodule update --init --recursive  # Pull any submodule updates
git add .
git commit -m "Update configs"
git push
```

On another machine:
```bash
cd ~/dotfiles
git pull
git submodule update --init --recursive  # Fetch/update powerlevel10k
stow zsh  # Reapply if needed
```
