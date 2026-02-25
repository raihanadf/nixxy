{pkgs, ...}: {
  # System packages
  environment.systemPackages = [
    pkgs.vim
    pkgs.wget
    pkgs.pfetch
    pkgs.neovim
    pkgs.php83
    pkgs.php83Packages.composer
    pkgs.fd
    pkgs.tmux
    pkgs.gnupg
    pkgs.fzf
    pkgs.bat
    pkgs.grc
    pkgs.bat
    pkgs.git
    pkgs.gh
    pkgs.ripgrep
    pkgs.stow
    pkgs.jdk
    pkgs.jdk17
    pkgs.tree
    pkgs.tree-sitter
    pkgs.texlive.combined.scheme-full
  ];

  nix.settings.experimental-features = "nix-command flakes";

  # Homebrew
  homebrew = {
    enable = true;
    brews = [
      "borders"
      # "sketchybar"
      "clisp"
      "fortune"
      "ghostscript"
      "imagemagick"
      "neofetch"
      "pyenv"
    ];
    casks = [
      "aerospace"
      "android-platform-tools"
      "ghostty"
      "kitty"
      "linearmouse"
      "prismlauncher"
      "visual-studio-code@insiders"
      "helium-browser"
      "insomnia"
      "skim"
    ];
  };

  # System PATH
  environment.systemPath = ["/opt/homebrew/bin"];

  # Enable fish at system level
  programs.fish.enable = true;
  environment.shells = [pkgs.fish];

  # Environment variables (system-wide)
  environment.variables = {
    nginxdir = "/usr/local/var/www";
    nvimdir = "$HOME/.config/nvim";
  };

  # User config
  system.primaryUser = "raihan";
  users.knownUsers = ["raihan"];
  users.users.raihan = {
    uid = 501;
    home = "/Users/raihan";
    shell = pkgs.fish;
  };

  # Used for backwards compatibility
  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
