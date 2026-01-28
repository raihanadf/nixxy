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
    pkgs.ripgrep
  ];

  nix.settings.experimental-features = "nix-command flakes";

  # Homebrew
  homebrew = {
    enable = true;
    brews = [
      "borders"
      "sketchybar"
    ];
    casks = [
      "aerospace"
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
