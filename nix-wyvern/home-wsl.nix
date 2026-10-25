# home for wyvern under wsl: the shell, the js toolchain, the agents and the
# terminal dotfiles. the desktop half of home.nix (kitty, dwm scripts, rofi,
# teams, games, fonts, the plasma seed) stays behind with the metal.
{
  pkgs,
  dotfiles,
  llm-agents,
  ...
}: {
  imports = [
    ./modules/fish.nix
    ./modules/node.nix
  ];

  home.username = "raihan";
  home.homeDirectory = "/home/raihan";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    tmux
    llm-agents.claude-code
    llm-agents.omp
    grc
    fzf
    fd
    bat
  ];

  home.file.".gitconfig".source = "${dotfiles}/dots/gitconfig";
  home.file.".vimrc".source = "${dotfiles}/dots/vimrc";
  home.file.".tmux.conf".source = "${dotfiles}/dots/tmux.conf";

  xdg.configFile."nvim".source = "${dotfiles}/config/nvim";
  xdg.configFile."starship.toml".source = "${dotfiles}/config/starship.toml";

  programs.home-manager.enable = true;
}
