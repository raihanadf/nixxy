{
  config,
  pkgs,
  username,
  ...
}: {
  home.username = username;
  home.homeDirectory = "/home/${username}";

  imports = [
    ./modules/fish.nix
  ];

  # Packages
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
    alejandra
  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Required for backwards compatibility, do not change
  home.stateVersion = "24.11";
}
