{
  description = "Raihan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # Formatter: run `nix fmt` to format all .nix files
    formatter.${system} = pkgs.alejandra;

    darwinConfigurations."loong" = nix-darwin.lib.darwinSystem {
      modules = [

        # git revision for darwin-version
        ./darwin.nix
        ({ ... }: {
          system.configurationRevision = self.rev or self.dirtyRev or null;
        })

        # home-manager integration
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";  # Fixes the clobber error
          home-manager.users.raihan = import ./home.nix;
        }
      ];
    };
  };
}
