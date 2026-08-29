#!/usr/bin/env bash
# Install the Honcho skills for BOTH agents.
#
# claude-code reads ~/.claude/skills/<name>/SKILL.md and omp reads
# ~/.omp/skills/<name>/SKILL.md -- same format, two directories, so each skill
# is written to both. Re-run to update.
set -euo pipefail

RAW="https://raw.githubusercontent.com/plastic-labs/honcho/main/skills"
TARGETS=("$HOME/.claude/skills" "$HOME/.omp/skills")

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# --- upstream skills --------------------------------------------------------
# honcho-memory: the recall/record loop and session/peer design.
# honcho-cli:    how to drive and introspect the deployment.
for skill in honcho-memory honcho-cli; do
  say "Fetching $skill"
  body="$(curl -fsSL "$RAW/$skill/SKILL.md")"
  for base in "${TARGETS[@]}"; do
    mkdir -p "$base/$skill"
    printf '%s\n' "$body" > "$base/$skill/SKILL.md"
    echo "  -> $base/$skill/SKILL.md"
  done
done

# --- local wiring -----------------------------------------------------------
# The upstream skills describe Honcho in general and deliberately do not know
# which workspace, peer, or endpoint this machine uses. That is what this one
# supplies, plus the constraints specific to running on a 4B local model.
say "Writing honcho-wyvern (local wiring)"
read -r -d '' LOCAL <<'EOF' || true
---
name: honcho-wyvern
description: How this machine is wired into Honcho — the honcho-raihan workspace shared by wyvern and loong, which endpoint to use from where, and what the local 4B model can and cannot afford. Read together with honcho-memory (the loop) and honcho-cli (the commands).
allowed-tools: Bash(honcho:*), Bash(jq:*), Read, Grep
---

# Honcho on wyvern

A self-hosted Honcho runs on **wyvern** (the NixOS laptop). Both wyvern and
loong (the Mac) share one workspace, so memory recorded on either machine is
visible from the other.

## Wiring

- **Workspace:** `honcho-raihan` — the single shared workspace. Do not create
  per-machine workspaces; that would split the memory in half, which is exactly
  what this setup exists to avoid.
- **Human peer:** `raihan`. This is the peer to *observe* and build a
  representation of.
- **Assistant peer:** use `claude-code` or `omp` — whichever you are. Add
  yourself to sessions as a peer, but do not observe yourself.
- **Endpoint:** `http://127.0.0.1:8000` on wyvern; `http://wyvern-1:8000` from
  loong over tailscale. The CLI already has this in `~/.honcho/config.json`.

## Sessions

Scope a session to a coherent context — usually one repo or one ongoing piece
of work — and keep appending to it rather than opening a new session per
conversation. Honcho reasons over a session's messages together, so a handful
of fat sessions produce much better representations than many thin ones.

## What the local model changes

Inference is **fully local**: ollama on an RTX 2060 with 6 GB of VRAM, running
`qwen3:4b`. Nothing is sent to a cloud provider. That has consequences worth
respecting:

- **Prefer cheap reads.** `get_representation` and `get_session_context` are
  near-instant. Use them by default.
- **Keep `chat` at `minimal` or `low`.** The higher reasoning levels spend up
  to 10 tool iterations, and on a 4B model that is minutes, not seconds. Reach
  for `medium`+ only when a cheap read genuinely could not answer.
- **Recording is asynchronous — never poll for it.** The deriver processes in
  the background and is slower here than on hosted Honcho. Record and move on;
  the representation is richer next time, not this time.
- **Dreams are disabled.** Background consolidation would starve the deriver on
  a single 6 GB GPU. Do not try to `schedule_dream`.

## The loop

Unchanged from `honcho-memory`: recall before responding when personalization
helps, record both sides after each exchange. Read that skill for the detail.
EOF

for base in "${TARGETS[@]}"; do
  mkdir -p "$base/honcho-wyvern"
  printf '%s\n' "$LOCAL" > "$base/honcho-wyvern/SKILL.md"
  echo "  -> $base/honcho-wyvern/SKILL.md"
done

say "Installed"
for base in "${TARGETS[@]}"; do
  echo "$base:"; ls -1 "$base" | sed 's/^/  /'
done
