# Firefox, tuned for this laptop.
#
# - video decoding on the GPU: VA-API through nvidia-vaapi-driver in the
#   default (PRIME sync) entry, intel-media-driver in `hybrid`. The RTX 2060
#   (Turing) has no AV1 decoder, so AV1 is off and sites like YouTube fall
#   back to VP9, which the GPU does decode.
# - webrender, dmabuf and accelerated canvas forced on, larger canvas/font
#   caches, faster paint/network settings (Betterfox "fastfox" values), and
#   no telemetry, studies or pocket running in the background.
# - smooth scrolling with macos-like physics.
#
# Preferences are defaults, not locked, so they can still be changed in
# about:config.
{
  pkgs,
  lib,
  ...
}: {
  programs.firefox = {
    enable = true;
    preferencesStatus = "default";
    preferences = {
      # userChrome.css (traffic-light window buttons, see modules/gnome.nix)
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

      # gpu video decoding
      "media.ffmpeg.vaapi.enabled" = true;
      "media.hardware-video-decoding.force-enabled" = true;
      "media.rdd-ffmpeg.enabled" = true;
      "media.av1.enabled" = false;

      # gpu compositing and canvas
      "gfx.webrender.all" = true;
      "widget.dmabuf.force-enabled" = true;
      "layers.acceleration.force-enabled" = true;
      "gfx.canvas.accelerated" = true;
      "gfx.canvas.accelerated.cache-items" = 32768;
      "gfx.canvas.accelerated.cache-size" = 4096;
      "gfx.content.skia-font-cache-size" = 32;

      # paint and caches
      "content.notify.interval" = 100000;
      "browser.cache.jsbc_compression_level" = 3;
      "image.mem.decode_bytes_at_a_time" = 32768;
      "media.memory_cache_max_size" = 65536;
      "media.cache_readahead_limit" = 7200;
      "media.cache_resume_threshold" = 3600;

      # network
      "network.http.max-connections" = 1800;
      "network.http.max-persistent-connections-per-server" = 10;
      "network.http.max-urgent-start-excessive-connections-per-host" = 5;
      "network.http.pacing.requests.enabled" = false;
      "network.dnsCacheExpiration" = 3600;
      "network.ssl_tokens_cache_capacity" = 10240;

      # scrolling
      "general.smoothScroll.msdPhysics.enabled" = true;
    };
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
    };
  };

  # VA-API driver selection. nvidia-vaapi-driver needs the direct backend and
  # firefox's RDD sandbox off to reach the GPU.
  hardware.graphics.extraPackages = [pkgs.intel-media-driver];
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };
  specialisation.hybrid.configuration.environment.sessionVariables.LIBVA_DRIVER_NAME = lib.mkForce "iHD";
}
