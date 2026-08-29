#!/usr/bin/env bash
# Claude Code status line: default segments (model, cwd, git branch)
# plus a live Honcho (plastic-labs/honcho) connectivity indicator.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")

# Git branch, skipping optional locks so this stays fast and non-blocking
git_branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
fi

# Honcho connectivity check: MCP worker service must be active AND the
# underlying Honcho API must actually answer a health check (not just
# "process is alive").
if curl -sf -m 1 http://127.0.0.1:8000/health >/dev/null 2>&1 && systemctl is-active --quiet honcho-mcp.service; then
  HONCHO_STATUS="🧠 Honcho"
  HONCHO_COLOR="\033[32m"    # green: on and healthy
else
  HONCHO_STATUS="🧠 Honcho off"
  HONCHO_COLOR="\033[2;31m"  # dim red: off / unreachable
fi

DIM="\033[2m"
RESET="\033[0m"

line="${DIM}${model}${RESET} ${DIM}${dir_name}${RESET}"
if [ -n "$git_branch" ]; then
  line="${line} ${DIM}(${git_branch})${RESET}"
fi
line="${line} ${HONCHO_COLOR}${HONCHO_STATUS}${RESET}"

printf "%b\n" "$line"
