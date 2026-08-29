# Local embeddings for Honcho. The LLM slots are remote -- see the OpenRouter
# wiring in modules/honcho-bootstrap.nix.
#
# This module used to run qwen3:4b on the RTX 2060 for derivation, dialectic
# and summaries. It doesn't any more: every LLM slot now goes to OpenRouter,
# and the only thing left on this machine is the embedder. That single change
# removes the reason for nearly everything this file used to do.
#
# Embeddings cannot go remote with it. Neither OpenRouter nor DeepSeek exposes
# an embeddings endpoint, and the vector dimension is baked into the pgvector
# column, so the embedder has to stay local and stay nomic-embed-text (768-dim)
# unless the whole message_embeddings table is rebuilt.
#
# Consequences, all of them good:
#
#   - CPU build, not ollama-cuda. nomic-embed-text is ~300 MB and embeds a
#     message in milliseconds on a 9750H; the GPU bought nothing here. This
#     also drops the cudaCapabilities pin and the CUDA kernel compile that
#     came with it.
#   - The dGPU is now never touched by inference at all, so it sits in D3cold
#     permanently (modules/nvidia.nix has finegrained RTD3 on). That is the
#     ~50 W this machine was previously burning around the clock to keep a
#     model resident.
#   - Started at boot again. The old config forced `wantedBy = []` so a reboot
#     left the GPU cold, handing ownership to the `honcho` fish function. With
#     no VRAM at stake that tradeoff is gone -- and it was actively wrong now,
#     because Honcho embeds on *every* message: no embedder means pgvector
#     inserts fail, not merely that things get slower.
{pkgs, ...}: {
  services.ollama = {
    enable = true;

    # CPU build. If local inference ever comes back, this is the line to flip
    # to pkgs.ollama-cuda, along with restoring the cudaCapabilities = ["7.5"]
    # pin for the Turing card (recompiling only sm_75 rather than all nine
    # default targets).
    package = pkgs.ollama;

    # Honcho runs in Docker and reaches ollama over the bridge, so localhost is
    # not enough. Nothing off-box can reach this: 11434 is never opened in the
    # host firewall, only on the docker bridges below.
    host = "0.0.0.0";
    port = 11434;
    openFirewall = false;

    loadModels = ["nomic-embed-text"];

    environmentVariables = {
      # nomic-embed-text tops out at 8192; the old 16384 was sized for qwen3's
      # context and is meaningless for an embedder.
      OLLAMA_CONTEXT_LENGTH = "8192";

      # Cheap to hold now that it is ~300 MB of RAM rather than GBs of VRAM,
      # and the deriver embeds on every message, so a resident model avoids a
      # reload on essentially every request.
      OLLAMA_KEEP_ALIVE = "24h";
      OLLAMA_MAX_LOADED_MODELS = "1";
    };
  };

  # Let containers reach ollama over the docker bridges, without opening 11434
  # to the LAN or the tailnet.
  #
  # `docker0` alone is not enough: compose puts the honcho stack on its own
  # network, which shows up as a `br-<id>` interface, so the wildcard is what
  # actually matches the deriver. Traffic still has to arrive on a bridge --
  # nothing off-box can reach this port.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i docker0 -p tcp --dport 11434 -j nixos-fw-accept
    iptables -A nixos-fw -i br-+ -p tcp --dport 11434 -j nixos-fw-accept
  '';
}
