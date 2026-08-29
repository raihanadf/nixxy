{
  description = "raihan's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oh-my-pi.url = "github:can1357/oh-my-pi";

    # Suckless tools (only slock is built from here) and the dwm fork.
    suckless = {
      url = "github:raihanadf/suckless";
      flake = false;
    };
    dwm-niri = {
      url = "github:raihanadf/dwm-niri";
      flake = false;
    };
    # submodules=1 pulls in scripts/rofi-command-palette (git submodule).
    dotfiles = {
      url = "git+https://github.com/raihanadf/dotfiles.git?submodules=1";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    oh-my-pi,
    suckless,
    dwm-niri,
    dotfiles,
    ...
  }: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.wyvern = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit oh-my-pi suckless dwm-niri dotfiles;
        # Flake source path, so modules can reach vendored files (honcho-bootstrap).
        repo = self.outPath;
      };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = {inherit oh-my-pi dotfiles;};
          home-manager.users.raihan = import ./home.nix;
        }
      ];
    };
  };
}
