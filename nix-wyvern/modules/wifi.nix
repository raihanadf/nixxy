# Intel AX210 (PCI 0000:03:00.0) sometimes comes up wedged: iwlwifi's probe
# fails with "CSR_RESET = 0x10 ... probe with driver iwlwifi failed with
# error -110" and there is no wlan interface. Removing/rescanning or resetting
# the PCIe bridge doesn't help; a secondary bus reset of the card itself
# followed by a manual driver bind does. This does that at boot, only when
# the card has no driver bound.
{pkgs, ...}: {
  systemd.services.ax210-recover = {
    description = "Recover the AX210 wifi card when iwlwifi fails to probe it";
    wantedBy = ["multi-user.target"];
    before = ["NetworkManager.service"];
    after = ["systemd-modules-load.service" "systemd-udev-settle.service"];
    path = [pkgs.kmod pkgs.coreutils];
    serviceConfig.Type = "oneshot";
    script = ''
      dev=/sys/bus/pci/devices/0000:03:00.0
      modprobe iwlwifi
      for attempt in 1 2 3; do
        [ -e "$dev/driver" ] && exit 0
        echo "attempt $attempt: resetting the card"
        echo bus > "$dev/reset_method"
        echo 1 > "$dev/reset"
        sleep 1
        echo 0000:03:00.0 > /sys/bus/pci/drivers/iwlwifi/bind || true
        sleep 2
      done
      [ -e "$dev/driver" ]
    '';
  };
}
