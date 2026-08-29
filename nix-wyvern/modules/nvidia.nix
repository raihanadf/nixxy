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
    # Pinned to an exact version rather than `nvidiaPackages.latest`.
    #
    # `latest` is `selectHighestVersion production new_feature`, so it moves
    # whenever nixpkgs bumps either branch. A driver version change rotates the
    # Vulkan pipeline cache UUID, which invalidates Steam's fossilize replay
    # cache -- shadercache/<appid>/fozpipelinesv6/replay_cache.<fingerprint>.foz
    # -- and forces a full "Processing Vulkan Shaders" pass. For CS2 that is
    # 1.56M pipelines and ~60s on every launch until it completes again.
    #
    # 610.57.04 is nixpkgs' `new_feature`, and is the branch carrying the Turing
    # RTD3 fix relied on above; `production` (595.91.07) predates it, so the
    # stable channels are not an option here.
    #
    # To bump: copy version + hashes from `new_feature` in
    # pkgs/os-specific/linux/nvidia-x11/default.nix at the locked nixpkgs rev.
    # Expect one slow Steam shader pass afterwards.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "610.57.04";
      sha256_64bit = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
      sha256_aarch64 = "sha256-QCefrMBCmpOwuOyXv1k5Gj0iB2CYlPgnG3JToUw/j54=";
      openSha256 = "sha256-rQHOOOY4KL92Ww3KDwh+j4eGU7oNAH8LutZC5wmFnPo=";
      settingsSha256 = "sha256-ZEMo8I8Zc2Tq6RVDNYpAH+f094dUaZiBqO+5f6lIjRI=";
      persistencedSha256 = "sha256-aXmD2VY1RLlgAnlHhOUMWzvMyhI6JTClcFLm4imF/mA=";
    };

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
