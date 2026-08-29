{
  description = "raihan's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oh-my-pi.url = "github:can1357/oh-my-pi";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    oh-my-pi,
    ...
  }: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.wyvern = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit oh-my-pi;};
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {inherit oh-my-pi;};
          home-manager.users.raihan = import ./home.nix;
        }
      ];
    };
  };
}
