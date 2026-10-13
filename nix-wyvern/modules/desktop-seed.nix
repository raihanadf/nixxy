# Desktop state the dwm scripts write to at runtime, so it can't be a
# read-only home-manager symlink: the wallpaper, ~/.fehbg and mimeapps.list.
# gnome settings are declarative instead (dconf.settings in home.nix).
#
# ../home-seed mirrors $HOME. Each file is copied in only when it's missing,
# so a fresh install gets it and later changes survive rebuilds.
{lib, ...}: {
  home.activation.seedDesktop = lib.hm.dag.entryAfter ["writeBoundary"] ''
    (
      cd ${../home-seed}
      find . -type f | while read -r f; do
        if [ ! -e "$HOME/$f" ]; then
          mode=644
          [ -x "$f" ] && mode=755
          run install -Dm"$mode" "$f" "$HOME/$f"
        fi
      done
    )
  '';
}
