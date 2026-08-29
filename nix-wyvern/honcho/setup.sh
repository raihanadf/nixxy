#!/usr/bin/env bash
# One-time setup for the local Honcho stack ("honcho-raihan" workspace).
#
# Idempotent: safe to re-run. It will not regenerate the JWT secret once one
# exists, because doing so would invalidate every key already handed to a
# client. Run AFTER `nixos-rebuild switch` -- it needs docker, uv and ollama,
# all of which come from the nix side.
set -euo pipefail

PROFILE_DIR="$HOME/.honcho/profiles/local"
ENV_FILE="$PROFILE_DIR/.env"
TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.template"
WORKSPACE="honcho-raihan"
OLLAMA="http://127.0.0.1:11434"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

say "Preflight"
command -v docker >/dev/null || die "docker missing -- nixos-rebuild switch first"
command -v uv >/dev/null     || die "uv missing -- nixos-rebuild switch first"
docker info >/dev/null 2>&1  || die "cannot talk to docker. If you were just added to the
       'docker' group, that only applies to new logins -- log out and back in."

# The deriver calls these on every message; if they are missing Honcho fails at
# request time rather than at startup, which is much harder to read.
curl -fsS "$OLLAMA/api/tags" >/dev/null 2>&1 || die "ollama not responding on $OLLAMA"
for m in qwen3:4b nomic-embed-text; do
  curl -fsS "$OLLAMA/api/tags" | grep -qE "\"$m(:[^\"]*)?\"" \
    || die "ollama is missing model '$m' (services.ollama.loadModels should have pulled it)"
done
echo "docker, uv, ollama + both models: ok"

say "Installing honcho-cli"
uv tool install --upgrade honcho-cli
export PATH="$HOME/.local/bin:$PATH"
command -v honcho >/dev/null || die "honcho not on PATH after install"

say "Starting the stack once to create $PROFILE_DIR"
# LLM_OPENAI_API_KEY here only exists to skip the interactive provider wizard;
# the real routing is written into .env below.
if [ ! -d "$PROFILE_DIR" ]; then
  LLM_OPENAI_API_KEY=ollama honcho start
fi

say "Writing $ENV_FILE"
if [ -f "$ENV_FILE" ] && grep -q '^AUTH_JWT_SECRET=' "$ENV_FILE"; then
  SECRET="$(grep '^AUTH_JWT_SECRET=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
  echo "reusing the existing JWT secret (regenerating would void issued keys)"
else
  SECRET="$(openssl rand -hex 32)"
  echo "generated a new JWT secret"
fi
install -m 600 /dev/null "$ENV_FILE"
sed "s|__JWT_SECRET__|$SECRET|" "$TEMPLATE" > "$ENV_FILE"

say "Restarting the stack so .env takes effect"
honcho stop
honcho start

say "Waiting for the API"
for i in $(seq 1 60); do
  curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1 && break
  [ "$i" = 60 ] && die "API never came up; check: honcho status"
  sleep 2
done
echo "API healthy"

say "Minting an admin JWT"
ADMIN_JWT="$(docker compose -f "$PROFILE_DIR/docker-compose.yml" exec -T api \
  /app/.venv/bin/python scripts/generate_jwt.py --admin | tr -d '\r' | tail -1)"
[ -n "$ADMIN_JWT" ] || die "could not mint an admin JWT"

say "Pointing the CLI at the local stack"
honcho init --base-url http://127.0.0.1:8000 --api-key "$ADMIN_JWT"

say "Creating workspace '$WORKSPACE'"
honcho workspace create "$WORKSPACE"

say "Doctor"
honcho doctor || true

cat <<EOF

Done. The shared memory workspace is '$WORKSPACE'.

  Admin JWT (both machines use this; treat it like a password):
    $ADMIN_JWT

  On loong, point the same tooling at:
    http://wyvern-1:8000

Next: install the skills with ./skills.sh
EOF
