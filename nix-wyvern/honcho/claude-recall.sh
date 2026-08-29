#!/usr/bin/env bash
# Claude Code SessionStart hook: recall Honcho memory for this project.
#
# Mirrors omp's ~/.omp/agent/extensions/honcho.ts (same peers "raihan"/"omp",
# same session-id derivation) so Claude Code and omp share one memory instead
# of each tool building its own silo. Reads the honcho MCP server's URL/
# headers from Claude Code's own ~/.claude.json -- credentials live in
# exactly one place, not duplicated into this script.
set -euo pipefail

USER_PEER="raihan"
AGENT_PEER="omp"
CONFIG_FILE="$HOME/.claude.json"

URL=$(jq -r '.mcpServers.honcho.url // empty' "$CONFIG_FILE" 2>/dev/null)
AUTH=$(jq -r '.mcpServers.honcho.headers.Authorization // empty' "$CONFIG_FILE" 2>/dev/null)
WORKSPACE=$(jq -r '.mcpServers.honcho.headers["X-Honcho-Workspace-ID"] // empty' "$CONFIG_FILE" 2>/dev/null)
[ -n "$URL" ] && [ -n "$AUTH" ] || exit 0

# Same project shares one memory across clones/machines/branches (wyvern and
# loong are both my own laptops); unrelated projects that happen to share a
# directory name should not. Key off the git remote (origin, or the first
# configured remote) when one exists -- normalized so git@host:owner/repo.git
# and https://host/owner/repo agree -- and only fall back to the cwd basename
# for non-git directories (e.g. $HOME itself). Mirrors gitRemoteId() in
# extensions/honcho.ts exactly, so both tools land in the same bucket.
git_remote_id() {
  local url first
  url="$(git -C "$PWD" remote get-url origin 2>/dev/null)"
  if [ -z "$url" ]; then
    first="$(git -C "$PWD" remote 2>/dev/null | head -1)"
    [ -n "$first" ] || return 1
    url="$(git -C "$PWD" remote get-url "$first" 2>/dev/null)"
  fi
  [ -n "$url" ] || return 1
  url="${url%.git}"
  case "$url" in
    git@*) echo "${url#git@}" | sed 's/:/\//' ;;
    ssh://*) echo "${url#ssh://}" | sed 's#^git@##' ;;
    http://*|https://*) echo "$url" | sed -E 's#^https?://##' ;;
    *) echo "$url" ;;
  esac
}

raw_id="$(git_remote_id || true)"
[ -n "$raw_id" ] || raw_id="$(basename "$PWD")"
session_id="$(echo "$raw_id" | sed -E 's/^[^a-zA-Z0-9]+//; s/[^a-zA-Z0-9_-]/-/g')"
[ -n "$session_id" ] || exit 0

call() {
  curl -sS -m 8 "$URL" -X POST \
    -H "Authorization: $AUTH" \
    -H "X-Honcho-Workspace-ID: $WORKSPACE" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}" \
    2>/dev/null | grep '^data: ' | head -1 | sed 's/^data: //'
}

# get-or-create session + peers (cheap, idempotent)
call create_session "{\"session_id\":\"$session_id\"}" >/dev/null || exit 0
call add_peers_to_session "{\"session_id\":\"$session_id\",\"peers\":[{\"peer_id\":\"$USER_PEER\",\"observe_me\":true,\"observe_others\":true},{\"peer_id\":\"$AGENT_PEER\",\"observe_me\":false,\"observe_others\":true}]}" >/dev/null || exit 0

frame="$(call get_peer_context "{\"peer_id\":\"$USER_PEER\",\"session_id\":\"$session_id\"}")"
[ -n "$frame" ] || exit 0

inner="$(echo "$frame" | jq -r '.result.content[0].text // empty' 2>/dev/null)"
[ -n "$inner" ] && [ "$inner" != "null" ] || exit 0

known="$(echo "$inner" | jq -r '[.representation, .peer_card] | map(select(. != null and . != "")) | join("\n")' 2>/dev/null)"
[ -n "$known" ] && [ "$known" != "null" ] || exit 0

printf '<honcho-memory session="%s">\n%s\n</honcho-memory>\n' "$session_id" "$known"
