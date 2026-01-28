{pkgs, ...}: {
  imports = [
    ./modules/fish.nix
    ./modules/aerospace.nix
    ./modules/borders.nix
    ./modules/sketchybar.nix
  ];

  aerospace.enable = true;
  borders.enable = true;
  sketchybar.enable = true;

  home.stateVersion = "24.05";
  home.username = "raihan";
  home.homeDirectory = "/Users/raihan";
}
