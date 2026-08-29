# JavaScript toolchain: volta as the version manager, plus the runtimes and
# package managers nix ships as real packages.
#
# Volta downloads upstream Node/npm/yarn tarballs, which are linked against an
# FHS dynamic loader (/lib64/ld-linux-x86-64.so.2) that NixOS does not have.
# nixpkgs says as much in the volta derivation itself. The fix lives in
# configuration.nix: programs.nix-ld.enable, whose default library set already
# carries libstdc++ / zlib / openssl -- the exact libs volta's node misses.
{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    volta

    # Nix-managed runtimes, independent of the volta toolchain. bun and deno
    # are single binaries volta cannot manage at all; pnpm here is the fallback
    # for repos with no packageManager field.
    bun
    deno
    pnpm
  ];

  # Volta's default, but set explicitly so non-login contexts (dwm autostart,
  # systemd user units, rofi-launched apps) see the same toolchain as fish.
  home.sessionVariables.VOLTA_HOME = "${config.home.homeDirectory}/.volta";

  # modules/fish.nix already does `fish_add_path $HOME/.volta/bin`; this covers
  # every other shell and anything launched outside one.
  home.sessionPath = ["${config.home.homeDirectory}/.volta/bin"];
}
