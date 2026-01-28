{pkgs, ...}: {
  imports = [
    ./modules/fish.nix
    ./modules/aerospace.nix
    ./modules/borders.nix
  ];

  aerospace.enable = true;
  borders.enable = true;

  home.stateVersion = "24.05";
  home.username = "raihan";
  home.homeDirectory = "/Users/raihan";
}
