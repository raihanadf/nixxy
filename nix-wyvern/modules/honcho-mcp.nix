# Honcho MCP server for OMP -- lets `omp` on both wyvern and loong talk to
# the local Honcho instance (see modules/honcho.nix) as an MCP tool server.
#
# This is plastic-labs/honcho's mcp/ subdirectory: a Cloudflare Worker with
# no bindings beyond HONCHO_API_URL, so `wrangler dev` runs it fully locally
# -- no Cloudflare account, no deploy. ./honcho/mcp-setup.sh clones it and
# runs `bun install` into ~/.honcho/mcp-server/mcp; this module just runs
# `bun run dev` (== `wrangler dev`, default port 8787, bound to localhost)
# as a systemd service and, like honcho-tailnet, forwards it to the tailnet
# for loong.
{pkgs, ...}: {
  systemd.services.honcho-mcp = {
    description = "Honcho MCP server (local Cloudflare Worker) for OMP";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      HONCHO_API_URL = "http://127.0.0.1:8000";
    };
    serviceConfig = {
      # The mcp-setup.sh checkout may not exist yet on first boot after this
      # module is added -- failing and retrying is the normal path here,
      # same as honcho-tailnet.
      Restart = "always";
      RestartSec = 10;
      User = "raihan";
      WorkingDirectory = "/home/raihan/.honcho/mcp-server/mcp";
      ExecStart = "${pkgs.bun}/bin/bun run dev";
    };
  };

  # The worker binds to localhost only; forward it to the tailnet the same
  # way honcho-tailnet.service exposes the Honcho API itself.
  systemd.services.honcho-mcp-tailnet = {
    description = "Expose the local Honcho MCP server on the tailnet for loong";
    after = ["tailscaled.service" "honcho-mcp.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
      DynamicUser = true;
    };
    script = ''
      addr="$(${pkgs.tailscale}/bin/tailscale ip -4)"
      test -n "$addr" || { echo "no tailscale address yet"; exit 1; }
      exec ${pkgs.socat}/bin/socat \
        TCP-LISTEN:8787,bind="$addr",fork,reuseaddr \
        TCP:127.0.0.1:8787
    '';
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8787];
}
