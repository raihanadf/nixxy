{ pkgs, ... }: {
  imports = [
    ./modules/fish.nix
  ];

  home.stateVersion = "24.05";
  home.username = "raihan";
  home.homeDirectory = "/Users/raihan";
}
