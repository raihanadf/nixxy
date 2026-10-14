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
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  # GNOME on GDM. wyvern stays on 24/7 for honcho, so the login screen must
  # never suspend the machine on AC (gdm's default is 20 min idle).
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.autoSuspend = false;
  services.desktopManager.gnome.enable = true;
  # login screen matches the session: native 1x scale with 1.15x text and the
  # 32px capitaine cursor
  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        cursor-theme = "capitaine-cursors";
        cursor-size = lib.gvariant.mkInt32 32;
        text-scaling-factor = 1.15;
      };
    }
  ];
  # bundled apps that firefox, kitty and teams already cover, or that go unused
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany
    geary
    gnome-music
    gnome-contacts
    gnome-maps
    gnome-weather
    totem
    yelp
    simple-scan
  ];

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

  # Install firefox. userChrome.css (traffic-light window buttons, see
  # modules/gnome.nix) only loads with this pref on.
  programs.firefox.enable = true;
  programs.firefox.preferences."toolkit.legacyUserProfileCustomizations.stylesheets" = true;

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
    # cursor theme for gdm's login screen (see the gdm dconf profile above)
    capitaine-cursors
  ];

  system.stateVersion = "26.05";
}
