# Secure Boot through lanzaboote (signed systemd-boot + signed kernels), then a
# breeze plymouth splash into sddm.
#
# Stock NixOS GRUB can't do Secure Boot: the firmware rejects it unsigned, and
# signed it locks down and refuses unsigned kernels and modules. So the fallout
# GRUB is gone.
#
# NixOS has its own 1G esp (nvme0n1p4, fat uuid 33C9-2F18) mounted at /boot.
# Windows' 100M esp (nvme0n1p1) is too small for one generation (13M kernel +
# 56M initrd), so it's left to Windows. systemd-boot only lists Windows when
# it's on the same esp, so Windows boots from the firmware boot menu.
#
# Keys live in /var/lib/sbctl (sbctl create-keys) and are enrolled next to
# Microsoft's (sbctl enroll-keys -m) so Windows still boots.
#
# This firmware moves Windows Boot Manager back to the top of BootOrder and
# lanzaboote doesn't create an nvram entry, so activation (every boot and
# switch) creates "Linux Boot Manager" if it's missing and puts it first.
{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = [pkgs.sbctl];

  boot.loader.grub.enable = false;
  # lanzaboote replaces the systemd-boot module
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 3;
  # no kernel cmdline editing at the menu (init=/bin/sh would skip secure boot's point)
  boot.loader.systemd-boot.editor = false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    # ~70M per kernel+initrd pair, 1G esp
    configurationLimit = 8;
  };

  system.activationScripts.efiBootOrder = {
    supportsDryActivation = false;
    text = ''
      efi=${lib.getExe' pkgs.efibootmgr "efibootmgr"}
      sed=${pkgs.gnused}/bin/sed
      if [ -d /sys/firmware/efi/efivars ]; then
        lbm() { $efi | $sed -n 's/^Boot\([0-9A-F]\{4\}\)\* Linux Boot Manager.*/\1/p' | ${pkgs.coreutils}/bin/head -1; }
        id=$(lbm)
        if [ -z "$id" ]; then
          $efi -q -c -d /dev/nvme0n1 -p 4 -L "Linux Boot Manager" -l '\EFI\systemd\systemd-bootx64.efi' || true
          id=$(lbm)
        fi
        order=$($efi | $sed -n 's/^BootOrder: //p')
        if [ -n "$id" ] && [ "''${order%%,*}" != "$id" ]; then
          rest=$(echo "$order" | ${pkgs.coreutils}/bin/tr ',' '\n' | ${pkgs.gnugrep}/bin/grep -v "^$id$" | ${pkgs.coreutils}/bin/paste -sd,)
          $efi -q -o "$id''${rest:+,$rest}" || true
        fi
      fi
    '';
  };

  # breeze splash from the boot menu to the login screen. systemd in the initrd keeps
  # it up through stage 1, i915 early so the laptop panel has kms right away
  # (the panel hangs off the intel gpu even in prime sync), and the kernel and
  # systemd stay quiet underneath it.
  boot.plymouth = {
    enable = true;
    theme = "breeze";
    themePackages = [pkgs.kdePackages.breeze-plymouth];
  };
  boot.initrd.systemd.enable = true;
  boot.initrd.kernelModules = ["i915"];
  boot.initrd.verbose = false;
  boot.consoleLogLevel = 3;
  boot.kernelParams = ["quiet" "splash" "udev.log_level=3" "systemd.show_status=auto"];
}
