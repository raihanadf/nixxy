# User-level configuration for raihan, managed by Home Manager.
{
  config,
  pkgs,
  dotfiles,
  llm-agents,
  ...
}: let
  displayScript = pkgs.writeShellScript "display.sh" ''
    # display setup for dwm-niri multi-monitor

    # connect prime offload providers if discrete gpu drives external outputs
    if xrandr --listproviders 2>/dev/null | grep -q "Provider 1"; then
      xrandr --setprovideroutputsource 1 0 2>/dev/null || true
      xrandr --setprovideroutputsource 0 1 2>/dev/null || true
    fi

    # 1. autorandr profile match
    if command -v autorandr >/dev/null 2>&1; then
      if autorandr --change 2>/dev/null; then
        [ -x "$HOME/.fehbg" ] && "$HOME/.fehbg" 2>/dev/null || true
        exit 0
      fi
    fi

    # 2. saved arandr layout
    if [ -x "$HOME/.screenlayout/default.sh" ]; then
      "$HOME/.screenlayout/default.sh" 2>/dev/null || true
      [ -x "$HOME/.fehbg" ] && "$HOME/.fehbg" 2>/dev/null || true
      exit 0
    fi

    # 3. user custom display script
    if [ -x "$HOME/.config/dwm/display.sh" ]; then
      "$HOME/.config/dwm/display.sh" 2>/dev/null || true
      [ -x "$HOME/.fehbg" ] && "$HOME/.fehbg" 2>/dev/null || true
      exit 0
    fi

    # 4. fallback auto-detect: external primary on left, laptop on right
    internal="eDP-1"
    external=$(xrandr --query 2>/dev/null | awk '/ connected/ && !/eDP-1/ {print $1; exit}')

    if [ -n "$external" ]; then
      xrandr --output "$external" --auto --primary --output "$internal" --auto --right-of "$external" 2>/dev/null || true
    else
      xrandr --output "$internal" --auto --primary 2>/dev/null || true
    fi

    [ -x "$HOME/.fehbg" ] && "$HOME/.fehbg" 2>/dev/null || true
  '';
  # gpu mode switcher for nixos (wyvern)
  gpuModeSwitcher = pkgs.writeShellScript "gpu-mode-switcher.sh" ''
    # nvidia gpu mode switcher for nixos (wyvern)
    set -e

    USER_NAME="''${SUDO_USER:-$USER}"
    USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
    NIRI_CONFIG="$USER_HOME/.config/niri/config.kdl"
    RENDER_NVIDIA="/dev/dri/renderD129"
    RENDER_INTEL="/dev/dri/renderD128"

    log() {
      local level=$1
      shift
      case $level in
        info)  echo -e "\033[0;32m✓\033[0m $*" ;;
        warn)  echo -e "\033[1;33m!\033[0m $*" ;;
        error) echo -e "\033[0;31m✗\033[0m $*" >&2 ;;
      esac
    }

    notify() {
      local title=$1
      local message=$2
      local urgency=''${3:-normal}

      if [ -n "$SUDO_USER" ]; then
        local user_uid=$(id -u "$SUDO_USER")
        sudo -u "$SUDO_USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" \
          notify-send -u "$urgency" "$title" "$message" 2>/dev/null || true
      fi
    }

    die() {
      log error "$@"
      notify "GPU Mode Switcher" "Error: $*" critical
      exit 1
    }

    require_root() {
      [ "$EUID" -eq 0 ] || die "Need root access. Try: sudo $0 $*"
    }

    update_niri_render_device() {
      local device=$1
      [ -f "$NIRI_CONFIG" ] || return 0

      if grep -q 'render-drm-device' "$NIRI_CONFIG"; then
        sed -i "s|render-drm-device \".*\"|render-drm-device \"$device\"|" "$NIRI_CONFIG"
      else
        printf '\ndebug {\n    render-drm-device "%s"\n    wait-for-frame-completion-before-queueing\n}\n' "$device" >> "$NIRI_CONFIG"
      fi
      log info "Niri render device → $device"
    }

    switch_mode() {
      local mode=$1
      require_root "$mode"

      notify "GPU Mode Switcher" "Switching to $mode mode..."
      log info "Switching to $mode mode..."

      if [ "$mode" = "nvidia" ]; then
        local base_bin="/nix/var/nix/profiles/system/bin/switch-to-configuration"
        if [ ! -x "$base_bin" ]; then
          base_bin="/run/current-system/bin/switch-to-configuration"
        fi
        [ -x "$base_bin" ] || die "System switch tool not found"
        "$base_bin" boot
        update_niri_render_device "$RENDER_NVIDIA"
        log info "Configured bootloader: Dedicated NVIDIA mode (extended displays supported)"
        notify "GPU Mode Switcher" "Switched to dedicated mode (extended displays supported). Please reboot." normal
      elif [ "$mode" = "hybrid" ]; then
        local hybrid_bin="/nix/var/nix/profiles/system/specialisation/hybrid/bin/switch-to-configuration"
        if [ ! -x "$hybrid_bin" ]; then
          hybrid_bin="/run/current-system/specialisation/hybrid/bin/switch-to-configuration"
        fi
        [ -x "$hybrid_bin" ] || die "Hybrid specialisation not found. Rebuild nixos first."
        "$hybrid_bin" boot
        update_niri_render_device "$RENDER_NVIDIA"
        log info "Configured bootloader: Hybrid mode (power saving enabled)"
        notify "GPU Mode Switcher" "Switched to hybrid mode (power saving enabled). Please reboot." normal
      fi

      log info "Done! Reboot to apply changes."

      if command -v rofi &>/dev/null; then
        local choice
        if [ -n "$SUDO_USER" ]; then
          choice=$(sudo -u "$SUDO_USER" DISPLAY=:0 rofi -dmenu -p "Reboot now?" -theme-str 'window {width: 200px;}' <<< $'Yes\nNo')
        else
          choice=$(rofi -dmenu -p "Reboot now?" -theme-str 'window {width: 200px;}' <<< $'Yes\nNo')
        fi
        if [ "$choice" = "Yes" ]; then
          log info "Rebooting..."
          systemctl reboot
        else
          log info "Reboot skipped."
          notify "GPU Mode Switcher" "Reboot skipped. Changes will apply on next boot." low
        fi
      fi
    }

    show_status() {
      log info "Current GPU configuration:"
      echo
      if [ -f "/run/current-system/specialisation-name" ] && [ "$(cat /run/current-system/specialisation-name)" = "hybrid" ]; then
        echo "  Active Mode: hybrid (PRIME render offload, battery saving enabled)"
        echo "  External Displays: Single screen only (HDMI wired to dGPU)"
      elif readlink -f /run/current-system | grep -q "specialisation/hybrid"; then
        echo "  Active Mode: hybrid (PRIME render offload, battery saving enabled)"
        echo "  External Displays: Single screen only (HDMI wired to dGPU)"
      else
        echo "  Active Mode: nvidia (Dedicated GPU, PRIME sync)"
        echo "  External Displays: Supported (Multi-monitor ready)"
      fi
      echo
    }

    show_help() {
      cat << EOF
NVIDIA Mode Switcher (NixOS)

Usage: $0 [command]

Commands:
    nvidia     Dedicated GPU (multi-monitor & extended displays supported)
    hybrid     Optimus hybrid (render offload, D3cold power saving on battery)
    status     Show current active mode
    help       Show this message

Examples:
    sudo $0 nvidia
    sudo $0 hybrid
    $0 status
EOF
    }

    case "''${1:-}" in
      nvidia|hybrid) switch_mode "$1" ;;
      status) show_status ;;
      help|--help|-h|"") show_help ;;
      *) die "Unknown command: $1" ;;
    esac
  '';

  # dotfiles tree with multi-monitor display hook and gpu switcher injected
  dotfilesPatched = pkgs.runCommand "dotfiles-patched" {} ''
    cp -r ${dotfiles} $out
    chmod -R u+w $out
    cp ${displayScript} $out/scripts/display.sh
    chmod +x $out/scripts/display.sh
    cp ${gpuModeSwitcher} $out/scripts/gpu-mode-switcher.sh
    chmod +x $out/scripts/gpu-mode-switcher.sh

    # insert multi-monitor setup before redshift
    sed -i '/redshift -P -O 6000K/i # multi-monitor display setup\n$HOME/.dotfiles/scripts/display.sh\n' $out/scripts/autostart.sh
  '';
in {
  imports = [
    ./modules/fish.nix
    ./modules/node.nix
    ./modules/desktop-seed.nix
  ];

  home.username = "raihan";
  home.homeDirectory = "/home/raihan";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    kitty
    tmux
    # Microsoft killed the native Linux Teams client; nixpkgs' `teams` is
    # aarch64-darwin only. This is the community Electron wrapper.
    teams-for-linux
    wget
    # agents from llm-agents.nix (flake input): prebuilt, no local compiles
    llm-agents.claude-code
    llm-agents.claude-desktop
    llm-agents.omp
    grc
    fzf
    fd
    bat
    # minecraft launcher, Diegiwg's cracked fork (offline accounts) built
    # from source on nixpkgs' recipe; the wrapper bundles jdk25/21/17/8
    (prismlauncher.override {
      prismlauncher-unwrapped = prismlauncher-unwrapped.overrideAttrs (_: {
        src = fetchFromGitHub {
          owner = "Diegiwg";
          repo = "PrismLauncher-Cracked";
          tag = "11.0.3";
          hash = "sha256-pFIDOP03I76r14bXoKL7tEEaLlGFJ10MqMgGR4D/mvE=";
        };
      });
    })
    # kitty's font (dotfiles kitty.conf: CaskaydiaCove NF)
    nerd-fonts.caskaydia-cove
    nerd-fonts.jetbrains-mono
  ];

  # Whole dotfiles tree at ~/.dotfiles — the dwm autostart and keybinds
  # reference $HOME/.dotfiles/scripts/*.
  home.file.".dotfiles".source = dotfilesPatched;

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

  # autorandr is x11-only and exits 1 under plasma wayland; dwm runs it from
  # display.sh instead, so the xdg autostart entry only produces a failed unit.
  xdg.configFile."autostart/autorandr.desktop".text = "[Desktop Entry]\nHidden=true\n";

  programs.home-manager.enable = true;
}
