# Declarative provisioning + backup for the self-hosted Honcho stack.
#
# Everything the original manual setup did by hand -- `uv tool install
# honcho-cli`, the first `honcho start` to generate the profile, the custom
# .env block (local ollama wiring), the MCP worker checkout pinned to a rev,
# the omp/claude MCP wiring with a minted bearer token -- now happens once per
# machine by honcho-bootstrap.service. Every step is idempotent: on an
# existing machine the unit is a fast no-op; on a fresh desktop it provisions
# everything and starts the stack. `honcho {start,stop,restart}` (the fish
# function) is then the only command ever needed.
#
# Secrets never live in this repo: AUTH_JWT_SECRET is generated per machine,
# and the bearer tokens for omp/claude/honcho-cli are minted locally from it
# (HS256, claims {t, ad} -- the same shape the original setup used).
#
# Agent-facing files (omp extension, claude hook/statusline/settings, the
# shared AGENTS/CLAUDE.md context, and the skills) are vendored under
# nix-wyvern/honcho/ and copied into place on every boot -- the repo is the
# source of truth. omp's config.yml is copied only when missing, so local
# preference edits survive.
#
# Data: honcho-backup.timer pg_dumps the postgres database nightly, keeping
# the 7 newest dumps in ~/.honcho/backups. A fresh machine starts empty;
# restore with `honcho restore [dumpfile]` (fish function).
{
  pkgs,
  lib,
  repo,
  ...
}: let
  # The custom .env block appended to the honcho profile. The managed block
  # (ports, image pin) is written by honcho-cli's `start`; these keys are the
  # provider wiring + the generated JWT secret. `env` wins over config.toml,
  # and every model slot is pinned so nothing ever falls back to OpenAI's API.
  #
  # Delimited and versioned. The first cut of this block was appended once and
  # never revisited, so editing it here did nothing to an already-provisioned
  # machine. The markers below let the bootstrap replace a stale block in
  # place; bump envVersion whenever this template changes.
  envVersion = "3";

  envTemplate = ''
    # >>> nixxy-managed v3 >>>
    # Generated from modules/honcho-bootstrap.nix. Edits here are overwritten
    # when envVersion changes -- change the template, not this file.

    # [auth]
    # On, because the API is exposed to the tailnet for loong, and the tailnet
    # has a second user on it. The firewall rule is not the security boundary;
    # this is. Generated per machine, and preserved across template bumps --
    # rotating it would invalidate the bearer tokens already written into
    # ~/.omp/agent/mcp.json and ~/.claude.json.
    AUTH_USE_AUTH=true
    AUTH_JWT_SECRET=__AUTH_JWT_SECRET__

    # [provider]
    # OpenRouter, OpenAI-compatible, so TRANSPORT stays `openai` and only the
    # base URL and model change. Read at boot from ~/.honcho/openrouter-key
    # (0600, outside this repo) -- the key must never reach the nix store or
    # git. The embedding slot below points at local ollama, which ignores the
    # key entirely, so one variable serves both.
    LLM_OPENAI_API_KEY=__OPENROUTER_API_KEY__

    # [deriver] runs on every message -- the cost-sensitive slot
    # tencent/hy3: 295B MoE, 21B active, 262k context. Cheapest model on
    # OpenRouter that declares both tool calling and structured outputs, which
    # Honcho requires. Hy3 emits reasoning tokens by default (~50 even for a
    # trivial completion) and they bill at the completion rate, so effort is
    # pinned low here where volume is high.
    #
    # THINKING_EFFORT is a first-class field on the model config, NOT an
    # override: ModelOverrideSettings only carries api_key, api_key_env,
    # base_url and provider_params, and its model_config sets extra="ignore".
    # An OVERRIDES__REASONING_EFFORT key is therefore accepted and silently
    # discarded -- verified against the running container's parsed settings.
    # Valid values: none|minimal|low|medium|high|xhigh|max.
    DERIVER_MODEL_CONFIG__TRANSPORT=openai
    DERIVER_MODEL_CONFIG__MODEL=tencent/hy3
    DERIVER_MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    DERIVER_MODEL_CONFIG__THINKING_EFFORT=low
    # Hy3 supports real json_schema, unlike ollama which only did json_object.
    DERIVER_MODEL_CONFIG__STRUCTURED_OUTPUT_MODE=json_schema
    # Was 8000, sized for qwen3's 16k local context. This is a ceiling, not a
    # target -- raising it only costs when that much context actually exists.
    DERIVER_MAX_INPUT_TOKENS=16000

    # [embeddings] -- stays local, permanently
    # Neither OpenRouter nor DeepSeek exposes an embeddings endpoint, and
    # EMBEDDING_VECTOR_DIMENSIONS is baked into the pgvector column: changing
    # the model means rebuilding message_embeddings. nomic-embed-text is
    # 768-dim and runs on CPU (see modules/ollama.nix).
    EMBEDDING_MODEL_CONFIG__TRANSPORT=openai
    EMBEDDING_MODEL_CONFIG__MODEL=nomic-embed-text
    EMBEDDING_MODEL_CONFIG__OVERRIDES__BASE_URL=http://172.17.0.1:11434/v1
    EMBEDDING_VECTOR_DIMENSIONS=768

    # [dialectic] the `chat` endpoint, one slot per reasoning level
    # Low levels get Hy3; high and max get a stronger model. These fire only
    # when a question is deliberately asked, so the price difference is
    # irrelevant at that volume and the quality difference is not.
    DIALECTIC_MAX_INPUT_TOKENS=32000
    DIALECTIC_LEVELS__minimal__MODEL_CONFIG__TRANSPORT=openai
    DIALECTIC_LEVELS__minimal__MODEL_CONFIG__MODEL=tencent/hy3
    DIALECTIC_LEVELS__minimal__MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    DIALECTIC_LEVELS__low__MODEL_CONFIG__TRANSPORT=openai
    DIALECTIC_LEVELS__low__MODEL_CONFIG__MODEL=tencent/hy3
    DIALECTIC_LEVELS__low__MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    DIALECTIC_LEVELS__medium__MODEL_CONFIG__TRANSPORT=openai
    DIALECTIC_LEVELS__medium__MODEL_CONFIG__MODEL=tencent/hy3
    DIALECTIC_LEVELS__medium__MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    DIALECTIC_LEVELS__high__MODEL_CONFIG__TRANSPORT=openai
    DIALECTIC_LEVELS__high__MODEL_CONFIG__MODEL=deepseek/deepseek-v3.2-exp
    DIALECTIC_LEVELS__high__MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    DIALECTIC_LEVELS__max__MODEL_CONFIG__TRANSPORT=openai
    DIALECTIC_LEVELS__max__MODEL_CONFIG__MODEL=deepseek/deepseek-v3.2-exp
    DIALECTIC_LEVELS__max__MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1

    # [summary]
    SUMMARY_MODEL_CONFIG__TRANSPORT=openai
    SUMMARY_MODEL_CONFIG__MODEL=tencent/hy3
    SUMMARY_MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    SUMMARY_MODEL_CONFIG__THINKING_EFFORT=low

    # [dream] background consolidation
    # Still off, but for a new reason. It used to be off because a dream run
    # occupied the GPU and starved the deriver; inference is remote now, so the
    # remaining cost is money rather than contention. Flip to true to try it --
    # both slots are pinned so it can never fall through to OpenAI.
    DREAM_ENABLED=false
    DREAM_DEDUCTION_MODEL_CONFIG__TRANSPORT=openai
    DREAM_DEDUCTION_MODEL_CONFIG__MODEL=tencent/hy3
    DREAM_DEDUCTION_MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1
    DREAM_INDUCTION_MODEL_CONFIG__TRANSPORT=openai
    DREAM_INDUCTION_MODEL_CONFIG__MODEL=tencent/hy3
    DREAM_INDUCTION_MODEL_CONFIG__OVERRIDES__BASE_URL=https://openrouter.ai/api/v1

    # [app]
    GET_CONTEXT_MAX_TOKENS=32000
    # <<< nixxy-managed <<<
  '';

  # The MCP worker (.dev.vars): points the Cloudflare Worker at the local API.
  devVars = "HONCHO_API_URL=http://127.0.0.1:8000\n";

  # Pinned honcho repo revision the worker is checked out at.
  honchoRev = "82a92429b888727b2236820b863256067c7edc80";

  # Repo-owned agent files, vendored under honcho/ (the flake root IS
  # nix-wyvern/, so ${repo} already points at it).
  honchoDir = "${repo}/honcho";
in {
  environment.systemPackages = [pkgs.bun];

  # One-shot provisioning, run at boot. Everything is a fast no-op once done;
  # the omp/claude wiring runs only until ~/.honcho/.provisioned exists.
  systemd.services.honcho-bootstrap = {
    description = "Provision the self-hosted Honcho stack (idempotent)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    before = ["honcho-mcp.service"];
    # `before` only orders a unit, it never activates one -- without this the
    # service would never run and none of the repo-owned agent files below
    # would ever land on a fresh machine.
    wantedBy = ["multi-user.target"];
    path = [
      pkgs.git
      pkgs.uv
      pkgs.bun
      pkgs.docker
      pkgs.python3
      pkgs.gzip
      pkgs.gnugrep
      pkgs.gnused
      pkgs.findutils
      pkgs.coreutils
      # cmp, for copy_if_different. Without it every `cmp -s` test failed
      # open, so the copies below ran on every boot instead of only on drift.
      pkgs.diffutils
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "raihan";
      Group = "docker";
      Restart = "on-failure";
      RestartSec = 15;
    };
    script = ''
      set -euo pipefail
      export HOME=/home/raihan
      PROFILES=$HOME/.honcho/profiles/local
      MCPROOT=$HOME/.honcho/mcp-server
      MCPDIR=$MCPROOT/mcp
      CLI=$HOME/.local/bin/honcho
      STAMP=$HOME/.honcho/.provisioned
      HONCHO_DIR=${honchoDir}
      REPO=https://github.com/plastic-labs/honcho
      REV=${honchoRev}

      log() { echo "honcho-bootstrap: $*"; }

      # copy a repo-owned file into place when missing or drifted
      copy_if_different() {
        if [ ! -f "$2" ] || ! cmp -s "$1" "$2"; then
          mkdir -p "$(dirname "$2")"
          # These come from the nix store, so both source and any previous copy
          # are mode 4xx. Plain `cp` onto an existing read-only file is EACCES,
          # which killed the whole unit under `set -e`. Unlink first, then
          # restore write permission -- cp preserves the source's exec bit, so
          # claude-recall.sh stays executable and the rest stay 644.
          rm -f "$2"
          cp "$1" "$2"
          chmod u+w "$2"
          log "installed $2"
        fi
      }

      # --- honcho-cli -----------------------------------------------------------
      if [ ! -x "$CLI" ]; then
        log "installing honcho-cli"
        uv tool install honcho-cli
      fi

      # --- profile ---------------------------------------------------------------
      # init.sql must exist before the FIRST compose up: the database container
      # bind-mounts it, and a missing file makes docker create a directory in
      # its place -- pgvector would never initialize.
      if [ ! -f "$PROFILES/init.sql" ]; then
        log "writing init.sql (pgvector)"
        mkdir -p "$PROFILES"
        echo "CREATE EXTENSION IF NOT EXISTS vector;" > "$PROFILES/init.sql"
      fi

      # The first `honcho start` creates the profile (config.toml, compose,
      # managed .env) and brings the stack up. LLM_OPENAI_API_KEY skips the
      # interactive provider wizard; the real routing is in the custom block.
      if [ ! -f "$PROFILES/docker-compose.yml" ]; then
        log "creating profile and starting the stack"
        LLM_OPENAI_API_KEY=ollama "$CLI" start
      fi

      # --- custom .env block, versioned -----------------------------------------
      # Replaced in place whenever envVersion changes. The first cut of this
      # was append-once, guarded on a key name, so template edits silently
      # never reached an already-provisioned machine.
      ENV_CHANGED=0
      KEYFILE=$HOME/.honcho/openrouter-key
      if ! grep -qF '# >>> nixxy-managed v${envVersion} >>>' "$PROFILES/.env" 2>/dev/null; then
        # The API key lives outside the repo and outside the nix store. Without
        # it every LLM slot would 401 on every message, so a missing key leaves
        # the previous working .env untouched rather than breaking the stack.
        APIKEY=""
        if [ -r "$KEYFILE" ]; then
          APIKEY=$(tr -d ' \n\r' < "$KEYFILE")
        fi

        if [ -z "$APIKEY" ]; then
          log "ERROR: $KEYFILE missing or empty -- .env left unchanged."
          log "       printf '%s' 'sk-or-v1-...' > $KEYFILE && chmod 600 $KEYFILE"
          log "       then: systemctl restart honcho-bootstrap"
        else
          # Reuse the existing JWT secret. Regenerating it would invalidate the
          # bearer tokens already baked into ~/.omp/agent/mcp.json and
          # ~/.claude.json, silently cutting both agents off from honcho.
          SECRET=$(sed -n 's/^AUTH_JWT_SECRET=//p' "$PROFILES/.env" 2>/dev/null | head -1)
          if [ -z "$SECRET" ]; then
            log "no existing AUTH_JWT_SECRET, generating one"
            SECRET=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
          else
            log "preserving existing AUTH_JWT_SECRET"
          fi

          log "installing .env block v${envVersion}"
          # Drop any previous managed block: the marked form, then the original
          # unmarked one, which was appended last and so ran to end-of-file.
          sed -i '/^# >>> nixxy-managed /,/^# <<< nixxy-managed <<<$/d' "$PROFILES/.env"
          # Pre-nix setup.sh header: stale, and it interpolated the JWT secret
          # into a plaintext comment. Everything from it down was ours.
          sed -i '/^# Honcho server config for the fully-local wyvern stack\.$/,$d' "$PROFILES/.env"
          sed -i '/^# --- Auth ---/,$d' "$PROFILES/.env"

          # `|` as the sed delimiter: the OpenRouter key is base64-ish and can
          # contain `/`, which would terminate a `/`-delimited expression.
          sed -e "s|__AUTH_JWT_SECRET__|$SECRET|" \
              -e "s|__OPENROUTER_API_KEY__|$APIKEY|" <<'ENVEOF' >> "$PROFILES/.env"
      ${envTemplate}
      ENVEOF
          ENV_CHANGED=1
        fi
      fi

      # honcho-cli's managed block defaults auth OFF and wins over the custom
      # block; re-enforce it, then recreate the api container -- compose only
      # applies .env at create/recreate time, a plain restart won't re-read it.
      if grep -q '^AUTH_USE_AUTH=false$' "$PROFILES/.env" 2>/dev/null; then
        sed -i 's/^AUTH_USE_AUTH=false$/AUTH_USE_AUTH=true/' "$PROFILES/.env"
        ENV_CHANGED=1
      fi

      if [ "$ENV_CHANGED" = 1 ]; then
        log "recreating api + deriver containers to apply .env"
        docker compose -p honcho-local --project-directory "$PROFILES" up -d --force-recreate api deriver
      fi

      # wait for the api only when it is actually running: a stopped stack is
      # intentional (`honcho stop`) and must not stall boot for 30s
      if [ "$(docker inspect -f '{{.State.Running}}' honcho-local-api-1 2>/dev/null)" = true ]; then
        for i in $(seq 1 30); do
          if [ "$(docker inspect -f '{{.State.Health.Status}}' honcho-local-api-1 2>/dev/null)" = healthy ]; then
            break
          fi
          sleep 1
        done
      fi

      # --- MCP worker -----------------------------------------------------------
      if [ ! -d "$MCPDIR/node_modules" ]; then
        log "cloning honcho repo at pinned rev $REV"
        mkdir -p "$MCPROOT"
        git clone --depth 1 "$REPO" "$MCPROOT"
        git -C "$MCPROOT" fetch --depth 1 origin "$REV"
        git -C "$MCPROOT" checkout FETCH_HEAD
        log "installing worker dependencies"
        (cd "$MCPDIR" && bun install)
      fi

      if [ ! -f "$MCPDIR/.dev.vars" ]; then
        log "writing worker .dev.vars"
        printf '${devVars}' > "$MCPDIR/.dev.vars"
      fi

      # --- omp/claude MCP wiring, once per machine ------------------------------
      if [ ! -f "$STAMP" ]; then
        log "wiring omp and claude MCP configs"
        mkdir -p "$HOME/.omp/agent" "$HOME/.claude/hooks" "$HOME/.claude/skills" "$HOME/.omp/skills"
        python3 - "$PROFILES/.env" "$HOME/.omp/agent/mcp.json" "$HOME/.claude.json" "$HOME/.honcho/.admin-jwt" <<'PYEOF'
      import base64, hashlib, hmac, json, os, sys, datetime, urllib.request

      envfile, omp_mcp, claude_json, jwt_out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

      secret = None
      for line in open(envfile):
          if line.startswith("AUTH_JWT_SECRET="):
              secret = line.split("=", 1)[1].strip()
      assert secret, "AUTH_JWT_SECRET missing from .env"

      def b64(b):
          return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

      header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
      now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
      payload = b64(json.dumps({"t": now, "ad": True}, separators=(",", ":")).encode())
      sig = b64(hmac.new(secret.encode(), (header + "." + payload).encode(), hashlib.sha256).digest())
      token = header + "." + payload + "." + sig

      entry = {
          "type": "http",
          "url": "http://127.0.0.1:8787/",
          "headers": {
              "Authorization": "Bearer " + token,
              "X-Honcho-Workspace-ID": "honcho-raihan",
          },
      }

      # omp mcp.json: create when missing, patch in the honcho server otherwise
      if not os.path.exists(omp_mcp):
          with open(omp_mcp, "w") as f:
              json.dump({"mcpServers": {"honcho": entry}}, f, indent=2)
      else:
          data = json.load(open(omp_mcp))
          if "honcho" not in data.get("mcpServers", {}):
              data.setdefault("mcpServers", {})["honcho"] = entry
              json.dump(data, open(omp_mcp, "w"), indent=2)

      # claude.json: same, but a fresh machine has no file yet -- create it so
      # Claude Code has the honcho MCP server from the very first run
      if not os.path.exists(claude_json):
          with open(claude_json, "w") as f:
              json.dump({"mcpServers": {"honcho": entry}}, f, indent=2)
      else:
          data = json.load(open(claude_json))
          if "honcho" not in data.get("mcpServers", {}):
              data.setdefault("mcpServers", {})["honcho"] = entry
              json.dump(data, open(claude_json, "w"), indent=2)

      # the minted token for honcho-cli's client config (~/.honcho/config.json)
      with open(jwt_out, "w") as f:
          f.write(token)
      os.chmod(jwt_out, 0o600)

      # Get-or-create the workspace on the freshly provisioned stack. Fails
      # silently when the stack is down -- the next `honcho start` covers it.
      try:
          body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                             "params": {"name": "create_workspace",
                                        "arguments": {"workspace_id": "honcho-raihan"}}}).encode()
          req = urllib.request.Request("http://127.0.0.1:8787/", data=body, method="POST",
                             headers={"Authorization": "Bearer " + token,
                                      "X-Honcho-Workspace-ID": "honcho-raihan",
                                      "Content-Type": "application/json",
                                      "Accept": "application/json, text/event-stream"})
          urllib.request.urlopen(req, timeout=10).read()
      except Exception as e:
          print("honcho-bootstrap: workspace ensure skipped:", e)
      PYEOF
        # point honcho-cli at the local stack (client config); fail quietly,
        # the stack may legitimately be down (honcho stop)
        ADMIN_JWT=$(cat "$HOME/.honcho/.admin-jwt")
        "$CLI" init --base-url http://127.0.0.1:8000 --api-key "$ADMIN_JWT" >/dev/null 2>&1 \
          || log "honcho init (client config) failed -- stack down?"
        touch "$STAMP"
      fi

      # --- repo-owned agent files: the repo is the source of truth --------------
      copy_if_different "$HONCHO_DIR/omp-extension.ts" "$HOME/.omp/agent/extensions/honcho.ts"
      copy_if_different "$HONCHO_DIR/claude-recall.sh" "$HOME/.claude/hooks/honcho-recall.sh"
      copy_if_different "$HONCHO_DIR/claude-statusline.sh" "$HOME/.claude/statusline-command.sh"
      copy_if_different "$HONCHO_DIR/claude-settings.json" "$HOME/.claude/settings.json"
      copy_if_different "$HONCHO_DIR/agent-context.md" "$HOME/.omp/agent/AGENTS.md"
      copy_if_different "$HONCHO_DIR/agent-context.md" "$HOME/.claude/CLAUDE.md"
      for s in honcho-memory honcho-cli honcho-wyvern; do
        copy_if_different "$HONCHO_DIR/skills/$s/SKILL.md" "$HOME/.claude/skills/$s/SKILL.md"
        copy_if_different "$HONCHO_DIR/skills/$s/SKILL.md" "$HOME/.omp/skills/$s/SKILL.md"
      done
      copy_if_different "$HONCHO_DIR/skills/caveman/SKILL.md" "$HOME/.omp/skills/caveman/SKILL.md"
      # user preference file: only when missing, never clobber local edits
      if [ ! -f "$HOME/.omp/agent/config.yml" ]; then
        cp "$HONCHO_DIR/omp-config.yml" "$HOME/.omp/agent/config.yml"
        log "installed omp config.yml"
      fi
    '';
  };

  # Nightly pg_dump of the honcho database, 7 dumps kept.
  systemd.services.honcho-backup = {
    description = "Daily pg_dump backup of the honcho postgres database";
    after = ["docker.service"];
    wants = ["docker.service"];
    path = [pkgs.docker pkgs.gzip pkgs.gnugrep pkgs.findutils pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      User = "raihan";
      Group = "docker";
    };
    script = ''
      set -euo pipefail
      export HOME=/home/raihan
      if ! docker ps --format '{{.Names}}' | grep -q '^honcho-local-database-1$'; then
        echo "honcho stack not running; skipping backup"
        exit 0
      fi
      mkdir -p "$HOME/.honcho/backups"
      out="$HOME/.honcho/backups/honcho-$(date +%F-%H%M).sql.gz"
      docker exec honcho-local-database-1 pg_dump -U postgres postgres | gzip > "$out"
      ls -1t "$HOME/.honcho/backups"/honcho-*.sql.gz | tail -n +8 | xargs -r rm -f
    '';
  };

  systemd.timers.honcho-backup = {
    description = "Run the daily honcho backup";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
