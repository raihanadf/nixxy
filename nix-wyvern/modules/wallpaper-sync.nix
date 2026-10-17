# One wallpaper everywhere: change it on any desktop and every other desktop,
# the lock screen and sddm follow.
#
# a user path unit watches plasma's applet config. on change, the desktop
# whose image differs from the last synced one is the new pick; it's written
# to every desktop (plasma scripting), to kscreenlockerrc, and copied to
# /var/lib/wallpaper/current for sddm, which can't read $HOME. the sync's own
# writes trigger the unit again, find nothing new and stop there.
{pkgs, ...}: let
  state = "/var/lib/wallpaper";
  initial = ../home-seed/Pictures/Wallpapers/feud.jpg;

  sync = pkgs.writeShellScript "wallpaper-sync" ''
    set -eu
    export PATH=${pkgs.lib.makeBinPath [pkgs.coreutils pkgs.gnugrep pkgs.kdePackages.qttools pkgs.kdePackages.kconfig]}
    js() { qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

    images=$(js 'print(desktops().filter(function (d) { return d.wallpaperPlugin == "org.kde.image"; }).map(function (d) {
      d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
      return d.readConfig("Image");
    }).join("\n"))')
    last=$(cat ${state}/source 2>/dev/null || true)
    pick=$(printf '%s\n' "$images" | grep -v -x -F -e "$last" -e "" | head -1 || true)
    [ -n "$pick" ] || exit 0
    echo "new wallpaper: $pick"

    # 1. every desktop
    js "desktops().forEach(function (d) {
      d.wallpaperPlugin = 'org.kde.image';
      d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
      d.writeConfig('Image', '$pick');
    })"
    # 2. lock screen
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
      --group org.kde.image --group General --key Image "$pick"
    # 3. sddm: a real image file. wallpaper packages are directories, take
    # their largest image
    path=''${pick#file://}
    if [ -d "$path" ]; then
      path=$(ls -1 "$path"/contents/images/* | sort -V | tail -1)
    fi
    cp "$path" ${state}/.current.tmp
    mv ${state}/.current.tmp ${state}/current
    printf '%s' "$pick" > ${state}/source
  '';
in {
  # owned by raihan so the user unit can swap the file; seeded once
  systemd.tmpfiles.rules = [
    "d ${state} 0755 raihan users -"
    "C ${state}/current - - - - ${initial}"
  ];

  # theme.conf.user lands next to breeze's theme.conf in the merged system
  # profile. no extension needed, qt sniffs the format.
  environment.systemPackages = [
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${state}/current
    '')
  ];

  systemd.user.paths.wallpaper-sync = {
    wantedBy = ["graphical-session.target"];
    pathConfig.PathChanged = "%h/.config/plasma-org.kde.plasma.desktop-appletsrc";
  };
  systemd.user.services.wallpaper-sync = {
    description = "Sync the wallpaper to every desktop, the lock screen and sddm";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = sync;
    };
  };
}
