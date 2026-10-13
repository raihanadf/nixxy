# nixxy

Raihan's Nix configs.

- `nix-wyvern/` — NixOS laptop (`wyvern`): GNOME + dwm, Home Manager.
- `nix-darwin/` — macOS (`loong`): nix-darwin + Home Manager + Homebrew.

## Apply

```bash
# NixOS (wyvern)
sudo nixos-rebuild switch --flake ~/.nixxy/nix-wyvern#wyvern

# macOS (loong)
sudo nix run nix-darwin -- switch --flake ~/.nixxy/nix-darwin#loong
```
