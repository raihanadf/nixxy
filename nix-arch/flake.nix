{
  description = "Home Manager configuration for Arch WSL (Wyvern)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      
      # UPDATE: We import nixpkgs with the config to allow unfree software
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      
      username = "raihan";
    in {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        extraSpecialArgs = { inherit username; };

        modules = [
          ./home.nix
        ];
      };
    };
}
