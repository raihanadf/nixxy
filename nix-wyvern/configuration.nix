# System-level configuration: boot, hardware, services, desktop environment.
# User-level stuff (dotfiles, shell, per-user packages) lives in home.nix.
{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./modules/dwm.nix
    ./modules/nvidia.nix
    ./modules/power.nix
    ./modules/ollama.nix
    ./modules/honcho.nix
    ./modules/honcho-mcp.nix
    ./modules/honcho-bootstrap.nix
    ./modules/firefox.nix
    ./modules/boot.nix
    ./modules/wifi.nix
    ./modules/wallpaper-sync.nix
    ./modules/insightaccess.nix
  ];

  networking.hostName = "wyvern";

  # Enable networking
  networking.networkmanager.enable = true;

  # Tailscale, as a plain client (no subnet routing / exit node advertised).
  # `useRoutingFeatures = "client"` loosens reverse-path filtering so an exit
  # node would work if one is ever selected; openFirewall lets peers reach
  # UDP 41641 for direct connections instead of falling back to a DERP relay.
  # Note: sshd (:22) below is reachable from the tailnet because ts-input
  # accepts tailscale0 traffic; other interfaces stay firewalled.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    openFirewall = true;
    # every honcho client (omp, claude hooks, loong) dials wyvern, so the
    # node name is pinned on each boot instead of whatever `tailscale up` got
    extraSetFlags = ["--hostname=wyvern"];
  };

  # Inbound SSH. Reachable only from the tailnet: tailscaled's own ts-input
  # chain accepts everything arriving on tailscale0 before nixos-fw runs,
  # and nixos-fw drops :22 from every other interface, so sshd is never
  # exposed to LAN/WAN. pubkey auth only.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Set your time zone.
  time.timeZone = "Asia/Jakarta";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # KDE Plasma 6 on SDDM. the plasma session is wayland; dwm stays as an x11
  # session next to it. AC never suspends (seeded powerdevilrc): wyvern serves
  # honcho 24/7.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with `passwd`.
  users.users."raihan" = {
    isNormalUser = true;
    description = "Raihan";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.fish;
  };

  # Steam, game-ready. The module enables 32-bit graphics and the
  # steam-hardware controller udev rules; the NVIDIA driver libs (64+32-bit)
  # land in the FHS env via hardware.graphics.extraPackages, so
  # `nvidia-offload %command%` works as a launch option for dGPU games.
  # gamescope / mangohud / gamemode are in the FHS env for
  # `gamescope %command%`, `MANGOHUD=1 %command%`, `gamemoderun %command%`.
  programs.steam = {
    enable = true;
    extraPackages = with pkgs; [
      gamescope
      mangohud
      gamemode
    ];
    extraCompatPackages = [pkgs.proton-ge-bin];
    protontricks.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # GameMode daemon: CPU governor + renice boosts while a game is running.
  programs.gamemode.enable = true;

  # Enable fish system-wide (registers it in /etc/shells for login).
  programs.fish.enable = true;

  # FHS dynamic loader shim. Needed by volta (see modules/node.nix): the Node
  # tarballs it downloads expect /lib64/ld-linux-x86-64.so.2. The module's
  # default library set already includes libstdc++, zlib and openssl, so no
  # `libraries` list is needed here.
  programs.nix-ld.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable flakes and the new nix command
  nix.settings.experimental-features = ["nix-command" "flakes"];
  # hardlink identical files in the store; steam's 32/64-bit fhs envs and the
  # hybrid specialisation share a lot
  nix.settings.auto-optimise-store = true;
  # numtide's cache serves the llm-agents packages prebuilt (see flake.nix)
  nix.settings.extra-substituters = ["https://cache.numtide.com"];
  nix.settings.extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];

  # /etc/nixos points at the flake checkout, so plain `nixos-rebuild` finds it.
  systemd.tmpfiles.rules = ["L+ /etc/nixos - - - - /home/raihan/.nixxy/nix-wyvern"];

  # Minimal system-wide packages. Prefer home.nix for user-facing tools.
  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    gnupg
    openssl
    jq
  ];

  system.stateVersion = "26.05";
}
