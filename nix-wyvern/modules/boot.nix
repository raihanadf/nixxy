# GRUB with the Fallout pip-boy theme, NixOS and Windows in one menu.
#
# systemd-boot has no theming at all, so this is GRUB (EFI, on the NixOS ESP
# nvme0n1p5). Windows lives on its own ESP (nvme0n1p1, fat uuid D257-CB47)
# and is chainloaded from there, listed last.
#
# This firmware moves Windows Boot Manager back to the top of BootOrder and
# keeps booting the old systemd-boot entry, so GRUB is also installed as the
# removable fallback loader (EFI/BOOT/BOOTX64.EFI) and the systemd-boot files
# are removed on every switch: whichever entry the firmware picks on p5 ends
# up in GRUB.
{
  pkgs,
  lib,
  ...
}: let
  falloutTheme = pkgs.fetchFromGitHub {
    owner = "shvchk";
    repo = "fallout-grub-theme";
    rev = "b441e25a6d115614dc00ee6d11355d019a4969bf";
    sha256 = "1kxf2zv9azz1zz1hzjdzj5pgcyg5mdkl6f3vifr673ahvcrlpm3l";
  };
in {
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = false;
    device = "nodev";
    theme = falloutTheme;
    # the theme's fonts and layout are drawn for 1080p
    gfxmodeEfi = "1920x1080";
    extraEntries = ''
      menuentry "Windows" --class windows {
        insmod part_gpt
        insmod fat
        search --no-floppy --fs-uuid --set=root D257-CB47
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
    extraInstallCommands = ''
      esp=/boot/EFI
      ${pkgs.coreutils}/bin/install -D -m 0755 $esp/NixOS-boot/grubx64.efi $esp/BOOT/BOOTX64.EFI
      ${pkgs.coreutils}/bin/rm -rf $esp/systemd $esp/Linux /boot/loader
      # GRUB first, Windows Boot Manager after it
      efi=${lib.getExe' pkgs.efibootmgr "efibootmgr"}
      grub=$($efi | ${pkgs.gnused}/bin/sed -n 's/^Boot\([0-9A-F]\{4\}\)\* NixOS-boot.*/\1/p' | ${pkgs.coreutils}/bin/head -1)
      [ -n "$grub" ] || exit 0
      $efi | ${pkgs.gnused}/bin/sed -n 's/^Boot\([0-9A-F]\{4\}\)\* Linux Boot Manager.*/\1/p;s/^Boot\([0-9A-F]\{4\}\)\* Fallback Linux Boot Manager.*/\1/p' |
        while read -r stale; do $efi -q -b "$stale" -B; done
      rest=$($efi | ${pkgs.gnused}/bin/sed -n 's/^BootOrder: //p' | ${pkgs.coreutils}/bin/tr ',' '\n' | ${pkgs.gnugrep}/bin/grep -v "^$grub$" | ${pkgs.coreutils}/bin/paste -sd,)
      $efi -q -o "$grub''${rest:+,$rest}"
    '';
  };
}
