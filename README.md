# nix-darwin Bootstrap

My macOS system configuration using nix-darwin. zero to ready:
```bash
# install nix
sh <(curl -L https://nixos.org/nix/install)

# clone repo
git clone https://github.com/YOUR_USERNAME/nix-darwin.git ~/.nixxy/nix-darwin
cd ~/.nixxy/nix-darwin

# install nix-darwin
sudo nix run nix-darwin -- switch --flake .#loong
```
