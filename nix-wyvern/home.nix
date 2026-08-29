# User-level configuration for raihan, managed by Home Manager.
{
  config,
  pkgs,
  oh-my-pi,
  dotfiles,
  ...
}: {
  imports = [
    ./modules/fish.nix
  ];

  home.username = "raihan";
  home.homeDirectory = "/home/raihan";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    kdePackages.kate
    kitty
    wget
    claude-code
    oh-my-pi.packages.${pkgs.system}.default
    grc
    fzf
    fd
    bat
  ];

  # Whole dotfiles tree at ~/.dotfiles — the dwm autostart and keybinds
  # reference $HOME/.dotfiles/scripts/*.
  home.file.".dotfiles".source = dotfiles;

  # Home-level dotfiles (zsh/aerospace/sketchybar omitted: fish is managed
  # by home-manager and those targets are macOS-only).
  home.file.".Xresources".source = "${dotfiles}/dots/Xresources";
  home.file.".xinitrc".source = "${dotfiles}/dots/xinitrc";
  home.file.".gitconfig".source = "${dotfiles}/dots/gitconfig";
  home.file.".vimrc".source = "${dotfiles}/dots/vimrc";
  home.file.".ideavimrc".source = "${dotfiles}/dots/ideavimrc";
  home.file.".tmux.conf".source = "${dotfiles}/dots/tmux.conf";
  home.file.".rofi-commands.yaml".source = "${dotfiles}/dots/rofi-commands.yaml";

  # XDG configs (fish intentionally omitted — owned by ./modules/fish.nix).
  xdg.configFile."sxhkd".source = "${dotfiles}/config/sxhkd";
  xdg.configFile."kitty".source = "${dotfiles}/config/kitty";
  xdg.configFile."nvim".source = "${dotfiles}/config/nvim";
  xdg.configFile."rofi".source = "${dotfiles}/config/rofi";
  xdg.configFile."dunst".source = "${dotfiles}/config/dunst";
  xdg.configFile."zathura".source = "${dotfiles}/config/zathura";
  xdg.configFile."sxiv".source = "${dotfiles}/config/sxiv";
  xdg.configFile."networkmanager-dmenu".source = "${dotfiles}/config/networkmanager-dmenu";
  xdg.configFile."starship.toml".source = "${dotfiles}/config/starship.toml";

  programs.home-manager.enable = true;
}
