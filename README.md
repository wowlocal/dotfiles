# Dotfiles

My personal dotfiles managed with GNU Stow.

## Features

- **Fast zsh startup** (~50-80ms vs ~330ms) through lazy-loading
- **Modular configuration** - organized by application
- **Git version control** - track changes and sync across machines
- **Easy deployment** - one command to set up on new machines

## Installation

### Prerequisites

```bash
# Install Stow (if not already installed)
brew install stow
```

### Deploy Dotfiles

```bash
# Clone this repo (or initialize if already created)
cd ~/dotfiles

# Deploy zsh configuration
stow zsh

# Deploy other configurations as you add them
# stow nvim
# stow git
```

### Remove/Unstow

```bash
cd ~/dotfiles
stow -D zsh  # Removes symlinks
```

## Structure

```
dotfiles/
├── zsh/
│   ├── .zshrc              # Main zsh config
│   ├── .zprofile           # Login shell config
│   └── .config/zsh/        # Modular configs
│       └── aliases.zsh     # Additional aliases
└── README.md
```

## Optimizations

- **NVM lazy-loading**: Loads only when node/npm/nvm commands are used
- **Pyenv lazy-loading**: Defers full initialization until needed
- **Completion caching**: Regenerates only once per day
- **Minimal prompt**: Custom prompt replacing oh-my-zsh (207ms saved)

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
git add .
git commit -m "Update configs"
git push
```

On another machine:
```bash
cd ~/dotfiles
git pull
stow zsh  # Reapply if needed
```
