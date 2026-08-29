# System-level configuration: boot, hardware, services, desktop environment.
# User-level stuff (dotfiles, shell, per-user packages) lives in home.nix.
{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./modules/dwm.nix
    ./modules/nvidia.nix
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
  # Note: this does not open wyvern to the tailnet -- see
  # networking.firewall.trustedInterfaces if inbound access is ever wanted.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    openFirewall = true;
  };

  # Set your time zone.
  time.timeZone = "Asia/Jakarta";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
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

  # Install firefox.
  programs.firefox.enable = true;

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
