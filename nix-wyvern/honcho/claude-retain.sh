#!/usr/bin/env bash
# Claude Code Stop hook: write the finished exchange back to Honcho.
#
# Claude Code's half of omp's agent_end retain in ~/.omp/agent/extensions/honcho.ts:
# same peers "raihan"/"omp", same session-id derivation, same queue. The exchange
# is written to the queue file first and sent in the background, so the turn never
# waits on wyvern and nothing is lost while it is down: the next run (from either
# tool) sends the backlog oldest first. Failures go to ~/.cache/honcho-retain/error.log.
set -euo pipefail

USER_PEER="raihan"
AGENT_PEER="omp"
CONFIG_FILE="$HOME/.claude.json"
STATE_DIR="$HOME/.cache/honcho-retain"
mkdir -p "$STATE_DIR"

input="$(cat)"
transcript="$(echo "$input" | jq -r '.transcript_path')"
cwd="$(echo "$input" | jq -r '.cwd')"
cc_session="$(echo "$input" | jq -r '.session_id')"

URL=$(jq -r '.mcpServers.honcho.url // empty' "$CONFIG_FILE")
AUTH=$(jq -r '.mcpServers.honcho.headers.Authorization // empty' "$CONFIG_FILE")
WORKSPACE=$(jq -r '.mcpServers.honcho.headers["X-Honcho-Workspace-ID"] // empty' "$CONFIG_FILE")
if [ -z "$URL" ] || [ -z "$AUTH" ]; then
  echo "$(date '+%F %T') honcho mcp url/auth missing in $CONFIG_FILE" >>"$STATE_DIR/error.log"
  exit 0
fi

# last real prompt (not tool results, meta or compaction summaries) and the last
# text reply after it, main thread only
exchange="$(jq -c '
  select(.isSidechain != true and .isMeta != true and .isCompactSummary != true)
  | if .type == "user" then
      (.message.content | if type == "string" then . else ([.[]? | select(.type == "text").text] | join("\n")) end) as $t
      | if $t != "" and ($t | startswith("[Request interrupted") | not) then {r: "u", t: $t} else empty end
    elif .type == "assistant" then
      ([.message.content[]? | select(.type == "text").text] | join("\n")) as $t
      | if $t != "" then {r: "a", t: $t} else empty end
    else empty end
' "$transcript" | jq -s '
  reduce .[] as $m ({u: "", a: ""}; if $m.r == "u" then {u: $m.t, a: ""} else .a = $m.t end)
')"
user="$(echo "$exchange" | jq -r '.u')"
assistant="$(echo "$exchange" | jq -r '.a')"
[ -n "$user" ] && [ -n "$assistant" ] || exit 0

# stop can fire more than once per turn; skip an exchange already written
fingerprint="$(printf '%s\0%s' "$user" "$assistant" | cksum | cut -d' ' -f1)"
last_file="$STATE_DIR/$cc_session"
[ "$(cat "$last_file" 2>/dev/null)" != "$fingerprint" ] || exit 0

# same derivation as honcho-recall.sh / gitRemoteId() in extensions/honcho.ts
git_remote_id() {
  local url first
  url="$(git -C "$cwd" remote get-url origin 2>/dev/null)"
  if [ -z "$url" ]; then
    first="$(git -C "$cwd" remote 2>/dev/null | head -1)"
    [ -n "$first" ] || return 1
    url="$(git -C "$cwd" remote get-url "$first" 2>/dev/null)"
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
[ -n "$raw_id" ] || raw_id="$(basename "$cwd")"
session_id="$(echo "$raw_id" | sed -E 's/^[^a-zA-Z0-9]+//; s/[^a-zA-Z0-9_-]/-/g')"

call() {
  local body res
  body="$(jq -nc --arg name "$1" --argjson args "$2" '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: $name, arguments: $args}}')"
  res="$(curl -sS -m 15 "$URL" -X POST \
    -H "Authorization: $AUTH" \
    -H "X-Honcho-Workspace-ID: $WORKSPACE" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$body" | grep '^data: ' | head -1 | sed 's/^data: //')"
  if [ -z "$res" ] || echo "$res" | jq -e '.error or .result.isError' >/dev/null; then
    echo "$(date '+%F %T') $1 failed: ${res:-no response from $URL}" >>"$STATE_DIR/error.log"
    return 1
  fi
}

# queue first: a crash, a closed laptop or an unreachable wyvern can't drop it
queue="$STATE_DIR/queue"
mkdir -p "$queue"
# honcho caps a message at 25000 chars; a long paste becomes several messages, not a rejected one
jq -nc --arg s "$session_id" --arg u "$USER_PEER" --arg a "$AGENT_PEER" --arg ut "$user" --arg at "$assistant" '
  def parts($peer; $text): [range(0; $text | length; 24000) as $i | {peer_id: $peer, content: $text[$i:$i + 24000]}];
  {session_id: $s, messages: (parts($u; $ut) + parts($a; $at))}' \
  >"$queue/$(date +%s)-cc-$$-$RANDOM.json"
echo "$fingerprint" >"$last_file"

(
  # same mkdir lock as the omp extension; a lock older than 2 minutes is a dead run
  lock="$queue/.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    [ $(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock") )) -gt 120 ] || exit 0
    rm -rf "$lock" && mkdir "$lock"
  fi
  trap 'rm -rf "$lock"' EXIT
  for f in $(ls "$queue"/*.json 2>/dev/null | sort); do
    payload="$(cat "$f")"
    sid="$(echo "$payload" | jq -r '.session_id')"
    # peers are set up once per honcho session, not on every turn
    if [ ! -e "$STATE_DIR/ready-$sid" ]; then
      call create_session "$(jq -nc --arg s "$sid" '{session_id: $s}')" || exit 1
      call add_peers_to_session "$(jq -nc --arg s "$sid" --arg u "$USER_PEER" --arg a "$AGENT_PEER" \
        '{session_id: $s, peers: [{peer_id: $u, observe_me: true, observe_others: false}, {peer_id: $a, observe_me: false, observe_others: false}]}')" || exit 1
      touch "$STATE_DIR/ready-$sid"
    fi
    # a failed send may mean the session was deleted on the server; set it up again next run
    call add_messages_to_session "$payload" || { rm -f "$STATE_DIR/ready-$sid"; exit 1; }
    rm -f "$f"
  done
) >/dev/null 2>>"$STATE_DIR/error.log" &
disown
