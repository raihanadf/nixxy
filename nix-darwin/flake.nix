{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [ 
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
        ];

      # necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Homebrew
      homebrew = {
        enable = true;
        brews = [ "mariadb" ];
      };

      # Add Homebrew to PATH
      environment.systemPath = [ "/opt/homebrew/bin" ];

			# 1. enable fish and necessary stuff
      programs.fish = {
        enable = true;
        
        shellInit = ''
          # Add Homebrew to PATH
          fish_add_path /opt/homebrew/bin
        '';
      };
      
      environment.shells = [ pkgs.fish ];
      
      # Environment variables
      environment.variables = {
        nginxdir = "/usr/local/var/www";
        nvimdir = "$HOME/.config/nvim";
      };
      
      # Set primary user for homebrew and other user-specific options
      system.primaryUser = "raihan";
      
      users.knownUsers = [ "raihan" ];
      users.users.raihan = {
          uid = 501;
          home = "/Users/raihan";
          shell = pkgs.fish;
      };
					
      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#loong
    darwinConfigurations."loong" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}
