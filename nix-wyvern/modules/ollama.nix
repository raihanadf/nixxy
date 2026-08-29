# Local inference for Honcho's deriver and embeddings. See modules/honcho.nix.
#
# 6 GB of VRAM on the RTX 2060 Mobile is the whole budget, and the deriver runs
# an LLM pass on every message, so both models are sized to sit resident
# together (~3.2 GB) rather than thrash on each request.
{pkgs, ...}: {
  # Build CUDA kernels for this machine's GPU only.
  #
  # The default arch list spans nine targets (sm_75 through sm_121a). The
  # RTX 2060 is Turing = sm_75, so eight of the nine are compiled for hardware
  # that is not in this laptop -- across every .cu file in llama.cpp, which is
  # the overwhelming majority of an ollama-cuda build. Forward-compat PTX is
  # off for the same reason.
  #
  # This makes the build roughly a ninth of the work and shrinks the binary,
  # at the cost of portability: if this config is ever reused on a different
  # NVIDIA card, widen this list or ollama will not find a usable backend.
  nixpkgs.config = {
    cudaCapabilities = ["7.5"];
    cudaForwardCompat = false;
  };

  services.ollama = {
    enable = true;

    # `services.ollama.acceleration` is deprecated in current nixpkgs; the
    # package attribute is how you select the CUDA build now.
    package = pkgs.ollama-cuda;

    # Honcho runs in Docker and reaches ollama over the bridge, so localhost is
    # not enough. Nothing off-box can reach this: 11434 is never opened in the
    # host firewall, only on docker0 below.
    host = "0.0.0.0";
    port = 11434;
    openFirewall = false;

    # qwen3:4b  -- deriver/dialectic. Must support tool calling, which Honcho
    #              requires; 4b keeps headroom for the embedder alongside it.
    # nomic-embed-text -- 768-dim embeddings. Honcho defaults to OpenAI's
    #              1536-dim text-embedding-3-small, so EMBEDDING_VECTOR_DIMENSIONS
    #              must be set to 768 to match (done in the Honcho .env).
    loadModels = [
      "qwen3:4b"
      "nomic-embed-text"
    ];

    environmentVariables = {
      # Ollama defaults to a 4096-token context regardless of what the model
      # supports. Honcho routinely sends more than that, and the overflow is
      # silently truncated -- which looks like Honcho "forgetting" rather than
      # like an error. qwen3 handles 32k; 16k keeps the KV cache affordable
      # inside 6 GB while leaving real headroom.
      OLLAMA_CONTEXT_LENGTH = "16384";

      # Keep both models resident. The deriver fires on every message, and at
      # the default 5m idle unload it would pay a multi-second reload on most
      # requests. qwen3:4b (~2.6 GB) + nomic-embed-text (~0.3 GB) fit together.
      OLLAMA_KEEP_ALIVE = "24h";
      OLLAMA_MAX_LOADED_MODELS = "2";
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
