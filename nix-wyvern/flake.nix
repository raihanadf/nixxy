{
  description = "raihan's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    # prebuilt ai agents (claude code, claude desktop, omp) from numtide's
    # cache. no nixpkgs follows: the cache only hits on their own pin.
    llm-agents.url = "github:numtide/llm-agents.nix";
    # lerd (rootless-podman php dev env) for the InsightAccess V1 sites,
    # see modules/insightaccess.nix
    lerd = {
      url = "github:lerd-env/lerd-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # wyvern runs as a distro on windows (wsl.nix, migrate-wsl/)
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    suckless,
    dwm-niri,
    dotfiles,
    llm-agents,
    lerd,
    nixos-wsl,
    ...
  }: let
    system = "x86_64-linux";
  in {
    # the bare-metal install, retired on 2026-10-25 for windows + wsl. kept to
    # read from; nothing boots it any more
    nixosConfigurations.wyvern-metal = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit suckless dwm-niri dotfiles lerd;
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
          home-manager.extraSpecialArgs = {
            inherit dotfiles;
            llm-agents = llm-agents.packages.${system};
          };
          home-manager.users.raihan = import ./home.nix;
        }
      ];
    };

    # wyvern as it runs now, on windows 10 + wsl. the hostname matches, so a
    # plain `nixos-rebuild switch` picks this one. a fresh import tarball:
    # nix build .#nixosConfigurations.wyvern.config.system.build.tarballBuilder
    # then: sudo ./result/bin/nixos-wsl-tarball-builder (see migrate-wsl/README.md)
    nixosConfigurations.wyvern = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit lerd;
        repo = self.outPath;
      };
      modules = [
        nixos-wsl.nixosModules.default
        ./wsl.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = {
            inherit dotfiles;
            llm-agents = llm-agents.packages.${system};
          };
          home-manager.users.raihan = import ./home-wsl.nix;
        }
      ];
    };
  };
}
