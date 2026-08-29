# Host prerequisites for a self-hosted Honcho ("honcho-raihan" workspace).
#
# Honcho itself is not packaged in nixpkgs and is not managed declaratively
# here: upstream ships `honcho-cli`, which owns the docker compose stack (API,
# deriver, Postgres+pgvector, Redis) under ~/.honcho/profiles/local/ and pins
# the image digest itself. This module only provides what that CLI needs --
# Docker, uv, and the firewall hole for loong.
#
# Inference is local: modules/ollama.nix serves the deriver and embedding
# models. No LLM traffic leaves the laptop.
{pkgs, ...}: {
  virtualisation.docker = {
    enable = true;
    # Reclaim disk from dead honcho images after each image re-pin.
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users."raihan".extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    uv # `uv tool install honcho-cli`
    docker-compose # honcho-cli shells out to `docker compose`
  ];

  # Honcho's API, reachable from loong over the tailnet only -- never the LAN.
  #
  # This exposes it to the whole tailnet, which includes a second user
  # (ucilmenangis@). Honcho's AUTH_USE_AUTH must stay true so the JWT is what
  # actually gates access -- this rule is not the security boundary.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8000];

  # honcho-cli owns the compose file and rewrites it, so binding the API to the
  # tailnet by editing that file would not survive. Forward from the tailscale
  # address instead. It has to bind that address specifically rather than
  # 0.0.0.0, which would collide with compose's own 127.0.0.1:8000 listener.
  systemd.services.honcho-tailnet = {
    description = "Expose the local Honcho API on the tailnet for loong";
    after = ["tailscaled.service" "docker.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      # The tailscale address does not exist yet at boot, and the stack is
      # started by hand, so failing and retrying is the normal path here.
      Restart = "always";
      RestartSec = 10;
      DynamicUser = true;
    };
    script = ''
      addr="$(${pkgs.tailscale}/bin/tailscale ip -4)"
      test -n "$addr" || { echo "no tailscale address yet"; exit 1; }
      exec ${pkgs.socat}/bin/socat \
        TCP-LISTEN:8000,bind="$addr",fork,reuseaddr \
        TCP:127.0.0.1:8000
    '';
  };
}
