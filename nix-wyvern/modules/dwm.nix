# dwm + slock desktop, built from raihan's suckless / dwm-niri sources.
{
  config,
  pkgs,
  suckless,
  dwm-niri,
  ...
}: let
  # slock built from the suckless repo's slock/ subdir (background-image +
  # imlib2 patch, xinerama). Setuid is handled by security.wrappers below.
  slock = pkgs.slock.overrideAttrs (old: {
    src = "${suckless}/slock";
    buildInputs =
      (old.buildInputs or [])
      ++ (with pkgs; [imlib2 libxext libxrandr libxinerama]);
  });

  # dwm from the dwm-niri fork (scrolling layout, animations, overview).
  # Extra libs for the composite/render/damage-based overview.
  dwm = pkgs.dwm.overrideAttrs (old: {
    src = dwm-niri;
    # Drop the repo's install hook that shells out to a dotfiles script
    # ($HOME/.dotfiles/scripts/sync-command-palette.sh), absent in the sandbox.
    postPatch =
      (old.postPatch or "")
      + ''
        sed -i '/SUDO_USER/,/fi$/d' Makefile
      '';
    buildInputs =
      (old.buildInputs or [])
      ++ (with pkgs; [
        fontconfig
        freetype
        libxinerama
        libxft
        libxrender
        libxcomposite
        libxdamage
        libxext
      ]);
  });
in {
  # dwm as a selectable session (alongside KDE Plasma) in SDDM.
  services.xserver.windowManager.dwm = {
    enable = true;
    package = dwm;
  };

  # slock must be setuid root to read shadow and lock the session.
  security.wrappers.slock = {
    source = "${slock}/bin/slock";
    owner = "root";
    group = "root";
    setuid = true;
  };

  # slock's config.h drops privileges to group "nobody"; ensure it exists.
  users.groups.nobody = {};

  # Core X font providing the "6x13" XLFD slock renders its message with.
  fonts.packages = [pkgs.font-misc-misc];

  # Daemons the dotfiles bar/scripts talk to.
  services.upower.enable = true;
  services.udisks2.enable = true;
  hardware.bluetooth.enable = true;

  # Tools referenced by the dwm autostart / keybinds / dotfiles scripts.
  environment.systemPackages = with pkgs; [
    slock
    dmenu
    rofi
    sxhkd
    xss-lock
    dunst
    feh
    flameshot
    brightnessctl
    pamixer
    playerctl
    xclip
    xsel
    libnotify
    ranger
    redshift
    lxappearance
    xrdb
    xrandr
    xset
    # bar (autostart.sh) + dotfiles scripts
    xinput
    xsetroot
    xdotool
    scrot
    udiskie
    psmisc
    pywal
    imagemagick
    android-tools
    pulseaudio
    yq-go
    python3
    upower
    bluez
  ];
}
