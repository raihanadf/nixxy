# GRUB with the Fallout pip-boy theme, NixOS and Windows in one menu.
#
# systemd-boot has no theming at all, so this is GRUB (EFI, on the NixOS ESP
# nvme0n1p5). Windows lives on its own ESP (nvme0n1p1, fat uuid D257-CB47)
# and is chainloaded from there, listed last. The old systemd-boot files and
# its firmware entry stay on p5 as a fallback.
{pkgs, ...}: let
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
  };
}
