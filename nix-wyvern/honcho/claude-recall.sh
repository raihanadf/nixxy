#!/usr/bin/env bash
# Claude Code SessionStart + UserPromptSubmit hook: recall Honcho memory.
#
# One store: raihan's own representation (observer raihan, observed raihan).
# The "omp" peer only sends messages and observes nobody, so the deriver no
# longer writes every conclusion twice. Recall is not session-scoped: what
# honcho knows about raihan follows him across projects, tools and machines.
#
# SessionStart (startup, resume, clear, compact) injects the core memory.
# Each prompt then runs a semantic search with the prompt text and injects
# only conclusions this Claude session has not seen yet, so nothing is
# repeated and most prompts add zero tokens. Credentials come from the honcho
# MCP entry in ~/.claude.json, the same place Claude Code itself reads.
set -euo pipefail

USER_PEER="raihan"
CONFIG_FILE="$HOME/.claude.json"
STATE_DIR="$HOME/.cache/honcho-recall"
mkdir -p "$STATE_DIR"

input="$(cat)"
event="$(echo "$input" | jq -r '.hook_event_name')"
cc_session="$(echo "$input" | jq -r '.session_id')"
seen_file="$STATE_DIR/$cc_session"
touch "$seen_file"

URL=$(jq -r '.mcpServers.honcho.url // empty' "$CONFIG_FILE")
AUTH=$(jq -r '.mcpServers.honcho.headers.Authorization // empty' "$CONFIG_FILE")
WORKSPACE=$(jq -r '.mcpServers.honcho.headers["X-Honcho-Workspace-ID"] // empty' "$CONFIG_FILE")
if [ -z "$URL" ] || [ -z "$AUTH" ]; then
  echo "honcho memory offline: no honcho url/auth in $CONFIG_FILE"
  exit 0
fi

if [ "$event" = "SessionStart" ]; then
  : >"$seen_file"
  args="$(jq -nc --arg p "$USER_PEER" '{peer_id: $p, max_conclusions: 40}')"
else
  prompt="$(echo "$input" | jq -r '.prompt')"
  args="$(jq -nc --arg p "$USER_PEER" --arg q "${prompt:0:500}" '{peer_id: $p, search_query: $q, max_conclusions: 8}')"
fi

body="$(jq -nc --argjson args "$args" '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "get_peer_context", arguments: $args}}')"
frame="$(curl -sS -m 6 "$URL" -X POST \
  -H "Authorization: $AUTH" \
  -H "X-Honcho-Workspace-ID: $WORKSPACE" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "$body" 2>/dev/null | grep '^data: ' | head -1 | sed 's/^data: //' || true)"
if [ -z "$frame" ] || echo "$frame" | jq -e '.error or .result.isError' >/dev/null; then
  # only worth saying once per session, not on every prompt
  [ "$event" = "SessionStart" ] && echo "honcho memory offline: $URL did not answer (wyvern down or token expired)"
  exit 0
fi

context="$(echo "$frame" | jq -r '.result.content[0].text')"
card=""
# the peer card never changes mid-session, so only the session start carries it
[ "$event" = "SessionStart" ] && card="$(echo "$context" | jq -r '.peer_card // empty | if type == "array" then join("\n") else . end')"
# one conclusion per line; "[2026-10-07 18:08:25] text" -> "[2026-10-07] text", the time of day is noise
new_lines="$(echo "$context" | jq -r '.representation // ""' | grep '^\[' \
  | sed -E 's/^\[([0-9]{4}-[0-9]{2}-[0-9]{2}) [0-9:]+\]/[\1]/' | grep -v -x -F -f "$seen_file" || true)"
[ -n "$new_lines" ] || [ -n "$card" ] || exit 0

echo "$new_lines" >>"$seen_file"
printf '<honcho-memory>\n%s%s\n</honcho-memory>\n' "${card:+$card$'\n'}" "$new_lines"
