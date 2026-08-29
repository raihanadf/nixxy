# Honcho MCP server for OMP -- lets `omp` on both wyvern and loong talk to
# the local Honcho instance (see modules/honcho.nix) as an MCP tool server.
#
# This is plastic-labs/honcho's mcp/ subdirectory: a Cloudflare Worker with
# no bindings beyond HONCHO_API_URL, so `wrangler dev` runs it fully locally
# -- no Cloudflare account, no deploy. ./honcho/mcp-setup.sh clones it and
# runs `bun install` into ~/.honcho/mcp-server/mcp.
#
# Run with node, not bun: wrangler explicitly doesn't support being executed
# under the Bun runtime (`bun run dev`/`bunx wrangler` both hit it) -- the
# proxy<->workerd-inspector websocket handshake fails ("Unexpected server
# response: 101"), which either hangs every request forever or crashes
# outright depending on timing. bun is still fine/needed for `bun install`.
#
# WRANGLER_SEND_METRICS=false + SSL_CERT_FILE: workerd's sandbox has no CA
# bundle under a plain systemd service (NixOS normally injects SSL_CERT_FILE
# via shell profile scripts, which systemd units don't source), so Wrangler's
# telemetry POST to Cloudflare failed TLS validation and every single MCP
# request errored with "internal error" even though Honcho itself was never
# touched. Disabling telemetry root-causes it (also keeps this fully local,
# matching the rest of the Honcho setup); SSL_CERT_FILE is set too in case
# anything else here ever needs real TLS.
#
# HONCHO_API_URL is deliberately NOT set here as a process env var: Workers'
# `env` bindings don't come from the OS environment (systemd `Environment=`
# is invisible to the Worker), only from .dev.vars / wrangler.toml [vars] /
# --var. It's written to mcp/.dev.vars by mcp-setup.sh instead -- without
# that file the Worker silently falls back to the real https://api.honcho.dev
# and every call fails with a confusing "Invalid API key" (it's genuinely
# talking to the wrong server, not rejecting a bad token).
{pkgs, ...}: {
  systemd.services.honcho-mcp = {
    description = "Honcho MCP server (local Cloudflare Worker) for OMP";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      WRANGLER_SEND_METRICS = "false";
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      # The mcp-setup.sh checkout may not exist yet on first boot after this
      # module is added -- failing and retrying is the normal path here,
      # same as honcho-tailnet.
      Restart = "always";
      RestartSec = 10;
      User = "raihan";
      WorkingDirectory = "/home/raihan/.honcho/mcp-server/mcp";
      ExecStart = "${pkgs.nodejs}/bin/node node_modules/wrangler/wrangler-dist/cli.js dev --port 8787";
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
