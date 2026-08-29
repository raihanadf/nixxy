# User-level configuration for raihan, managed by Home Manager.
{
  config,
  pkgs,
  oh-my-pi,
  ...
}: {
  home.username = "raihan";
  home.homeDirectory = "/home/raihan";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    kdePackages.kate
    kitty
    wget
    claude-code
    oh-my-pi.packages.${pkgs.system}.default
  ];

  programs.home-manager.enable = true;
}
