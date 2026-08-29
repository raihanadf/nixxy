# NVIDIA RTX 2060 Mobile (TU106M, 10de:1f11, PCI 01:00.0) in PRIME offload mode.
#
# The laptop is Optimus: the Intel UHD 630 (PCI 00:02.0) drives the display and
# stays primary. The dGPU is used for offloaded graphics (`nvidia-offload cmd`)
# and, more importantly here, for CUDA -- ollama talks to the driver directly
# and does not need the offload wrapper.
#
# Runtime D3/fine-grained power management is ON: driver 610.43.02+ upstreamed
# the Turing GSP RTD3 fix (NVIDIA/open-gpu-kernel-modules#640, confirmed
# working by multiple reporters as of driver 610.43.02), and `nvidia-smi`
# here already reports 610.57.04. Idle GPU now drops to D3cold instead of
# sitting at D0 all the time.
#
# Known tradeoff: if this ever regresses to Ollama failing to grab the GPU
# right after an idle period (the exact failure this was previously pinned at
# D0 to avoid), the fix is to flip finegrained back to false and re-add
# `boot.extraModprobeConfig = "options nvidia NVreg_DynamicPowerManagement=0x00";`
#
# If a rebuild ever leaves X unusable, pick the previous generation in the
# systemd-boot menu.
{
  config,
  pkgs,
  ...
}: {
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Turing, so the open modules are the recommended path (nixpkgs says as
    # much) and match what already worked on Arch.
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    modesetting.enable = true;
    nvidiaSettings = true;

    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload`
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
