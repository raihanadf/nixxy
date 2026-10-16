# Desktop state that KDE and the dwm scripts write to at runtime, so it can't
# be a read-only home-manager symlink: plasma rc files (theme, panel, touchpad,
# shortcuts, display layout, power), the dwm wallpaper, ~/.fehbg and
# mimeapps.list.
#
# ../home-seed mirrors $HOME. Each file is copied in only when it's missing,
# so a fresh install boots with this exact desktop and later tweaks made from
# system settings survive rebuilds. To capture a tweak, copy the file back
# into home-seed.
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
