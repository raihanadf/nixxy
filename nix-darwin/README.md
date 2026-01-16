# nix-darwin Bootstrap

My macOS system configuration using nix-darwin. This repo gets my machine from zero to ready.

## Fresh Mac Setup

### 1. Install Nix

```bash
sh <(curl -L https://nixos.org/nix/install)
```

Close and reopen your terminal after installation.

### 2. Clone this repo

```bash
git clone https://github.com/YOUR_USERNAME/nix-darwin.git ~/.nixxy/nix-darwin
cd ~/.nixxy/nix-darwin
```

### 3. Install nix-darwin

First time only:

```bash
nix run nix-darwin -- switch --flake .#loong
```

After that, use:

```bash
darwin-rebuild switch --flake .#loong
```

## What's Installed

### Via Nix
- vim, neovim
- wget
- pfetch
- PHP 8.3 + Composer
- fd (better find)
- tmux
- gnupg
- fzf

### Via Homebrew
- MariaDB (auto-starts as service)

## Making Changes

1. Edit `flake.nix`
2. Run `darwin-rebuild switch --flake .#loong`

That's it. Changes apply immediately.

## Useful Commands

```bash
# Rebuild system
darwin-rebuild switch --flake .#loong

# List generations
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild --rollback

# Manage MariaDB
brew services start mariadb
brew services stop mariadb
brew services restart mariadb
```

## File Structure

```
.
├── flake.nix          # Main configuration
├── flake.lock         # Locked dependency versions
└── README.md          # This file
```

## Customization

The main configuration lives in `flake.nix`. Look for:
- `environment.systemPackages` - add nix packages here
- `homebrew.brews` - add homebrew formulas here
- `homebrew.casks` - add GUI apps here

## Notes

- User: raihan
- Shell: fish
- State version: 6
- Platform: aarch64-darwin (Apple Silicon)

If you reset your Mac, just follow the setup steps again. Everything's declarative.
