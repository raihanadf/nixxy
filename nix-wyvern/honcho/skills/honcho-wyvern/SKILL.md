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