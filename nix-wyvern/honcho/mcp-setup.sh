#!/usr/bin/env bash
# One-time (idempotent) setup for the Honcho MCP worker (plastic-labs/honcho,
# mcp/ subdirectory). It's a Cloudflare Worker run locally via `wrangler dev`
# -- no bindings beyond an env var, so no Cloudflare account is needed.
#
# Not packaged declaratively for the same reason honcho-cli isn't (see
# modules/honcho.nix): it owns a git checkout + bun-installed node_modules
# under ~/.honcho, mutable state that doesn't belong in the Nix store.
# modules/honcho-mcp.nix runs `bun run dev` from the directory this script
# creates. Run this AFTER nixos-rebuild switch -- it needs bun and git from
# the nix side.
set -euo pipefail

DEST="$HOME/.honcho/mcp-server"
REPO="https://github.com/plastic-labs/honcho.git"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

command -v bun >/dev/null || die "bun missing -- nixos-rebuild switch first"
command -v git >/dev/null || die "git missing -- nixos-rebuild switch first"

if [ -d "$DEST/.git" ]; then
  say "Updating existing checkout at $DEST"
  git -C "$DEST" fetch --depth 1 origin main
  git -C "$DEST" reset --hard origin/main
else
  say "Cloning $REPO (mcp/ only) into $DEST"
  rm -rf "$DEST"
  git clone --depth 1 --filter=blob:none --sparse "$REPO" "$DEST"
  git -C "$DEST" sparse-checkout set mcp
fi

say "Installing dependencies"
cd "$DEST/mcp"
bun install

say "Done."
cat <<EOF

Start/enable it with:
  sudo systemctl restart honcho-mcp.service honcho-mcp-tailnet.service

It talks to the Honcho API at 127.0.0.1:8000 (see modules/honcho-mcp.nix)
and is exposed to loong on the tailnet at wyvern-1:8787, same pattern as
honcho-tailnet.
EOF
