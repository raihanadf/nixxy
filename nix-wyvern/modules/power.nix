# CPU frequency management for an always-on laptop.
#
# wyvern stays powered 24/7 so honcho is reachable -- from here and from loong
# over the tailnet -- which makes it a server that happens to have a keyboard.
# The watts that matter on this box are the RTX 2060's, not the CPU's: the
# 9750H idles around 10 W while the dGPU sits at ~50 W whenever ollama holds a
# model resident (see modules/ollama.nix). So the CPU is tuned for
# responsiveness, not frugality, and the power budget is defended elsewhere.
#
# auto-cpufreq rather than a static governor or TLP: it is the only one of the
# three that reacts to AC vs battery on its own, and it drives intel_pstate's
# knobs (scaling_governor, EPP, no_turbo) directly instead of layering another
# policy daemon on top. TLP is deliberately absent -- the two fight over the
# same sysfs files. power-profiles-daemon likewise; plasma6 will bind to it if
# it is ever enabled, and then two things are writing the same governor.
{lib, ...}: {
  # plasma6 enables power-profiles-daemon, and nixpkgs asserts that ppd and
  # auto-cpufreq are never on together -- they drive the same sysfs knobs and
  # would fight. auto-cpufreq wins here, which is the deliberate trade: the
  # battery applet's Power Save / Balanced / Performance switcher in Plasma
  # goes inert, because that UI is a ppd frontend. The profiles below replace
  # it, chosen by AC vs battery rather than by hand.
  services.power-profiles-daemon.enable = lib.mkForce false;

  services.auto-cpufreq = {
    enable = true;

    settings = {
      # The profile that actually runs, since this machine lives on the
      # charger. `turbo = "auto"` leaves turbo available and lets the daemon
      # gate it per-interval on load and package temperature -- not pinned on,
      # which on a 45 W 9750H in a GL65 chassis just means sitting on the
      # thermal limit and throttling.
      charger = {
        governor = "performance";
        turbo = "auto";

        # intel_pstate runs in HWP mode here, so the governor alone does not
        # settle the question: the EPP hint is what the hardware p-state
        # selection actually weighs. Default is balance_performance; this makes
        # the bias explicit and consistent with the governor above.
        energy_performance_preference = "performance";
      };

      # Only reached when the laptop is genuinely unplugged, which for wyvern
      # is the exception. Nothing here needs to be fast on battery -- honcho's
      # deriver is asynchronous background work -- so this side gives up turbo
      # entirely to stretch the runtime.
      battery = {
        governor = "powersave";
        turbo = "never";
        energy_performance_preference = "power";
      };
    };
  };
}
