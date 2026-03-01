{ config, pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # ==========================================
  # IMPORT YOUR MAC CONFIGS HERE
  # ==========================================
  # Point this to wherever your Fish config lives in your repo.
  # For example, if it's one folder up in a 'modules' directory:
  imports = [
    ../nix-darwin/modules/fish.nix 
  ];

  # The exact tools you wanted to kickstart
  home.packages = with pkgs; [
    neovim
    wget
    volta
    claude-code
    stow
    grc
    less
    openssh
    git
    php83
    php83Packages.composer
    pfetch
    tmux
    gnupg
    fzf
    bat
    gh
    ripgrep
    tree
    tree-sitter
    fd
    python311
    pyenv
  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Required for backwards compatibility, do not change
  home.stateVersion = "24.11"; 
}
