# wyvern as a NixOS-WSL distro on windows 10, replacing the bare-metal install
# (configuration.nix). same hostname, same tailnet name, same server modules:
# honcho, ollama (cpu embedder), the insightaccess stack. everything that only
# made sense on the metal is gone: bootloader, nvidia, power, wifi, the
# desktops, steam, sound and printing.
#
# windows owns the hardware now. see migrate-wsl/README.md for the windows side
# (keep the vm alive, lid and sleep, memory cap) and the backup/restore steps.
{pkgs, ...}: {
  imports = [
    ./modules/ollama.nix
    ./modules/honcho.nix
    ./modules/honcho-mcp.nix
    ./modules/honcho-bootstrap.nix
    ./modules/insightaccess.nix
  ];

  wsl = {
    enable = true;
    defaultUser = "raihan";
    # windows' PATH in every shell turns each command lookup into ntfs reads
    interop.includePath = false;
    wslConf.network.hostname = "wyvern";
  };

  networking.hostName = "wyvern";

  # tailscale runs inside the distro, not on windows: windows 10 wsl is nat-only
  # (no mirrored networking), so this is what keeps wyvern reachable as
  # `wyvern` on the tailnet with ssh, :8000 and :8787 exactly as before.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    openFirewall = true;
    extraSetFlags = ["--hostname=wyvern"];
  };

  # tailnet only, same as before: ts-input accepts tailscale0 before nixos-fw,
  # and nothing else reaches the distro from outside anyway (wsl nat).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  time.timeZone = "Asia/Jakarta";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users."raihan" = {
    isNormalUser = true;
    description = "Raihan";
    extraGroups = ["wheel"];
    shell = pkgs.fish;
    # loong, so the restore can be pushed in before ~/.ssh is back
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYQDVVK9kqVlNHIOFxCnx8YXgQ81jpQfkbdHihg9xxn 17radf@gmail.com"
    ];
  };

  # nixos-wsl lets wheel sudo without a password; wyvern is reachable over the
  # tailnet, so keep asking like the bare-metal install did
  security.sudo.wheelNeedsPassword = true;

  programs.fish.enable = true;

  # volta's node tarballs expect /lib64/ld-linux-x86-64.so.2 (see modules/node.nix)
  programs.nix-ld.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.auto-optimise-store = true;
  nix.settings.extra-substituters = ["https://cache.numtide.com"];
  nix.settings.extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];

  # /etc/nixos points at the flake checkout, so plain `nixos-rebuild` finds it
  systemd.tmpfiles.rules = ["L+ /etc/nixos - - - - /home/raihan/.nixxy/nix-wyvern"];

  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    gnupg
    openssl
    jq
    wget
  ];

  system.stateVersion = "26.05";
}
