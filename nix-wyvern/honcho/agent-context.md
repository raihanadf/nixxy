## Honcho memory (self-hosted, MCP)

Memory runs on wyvern: `http://wyvern-1:8787/` (`127.0.0.1:8787` on wyvern), the `honcho` MCP server in `~/.omp/agent/mcp.json` and `~/.claude.json`. Workspace comes from the `X-Honcho-Workspace-ID` header: never pass `workspace_id`, never list/create workspaces.

Automatic in both tools, never do it by hand or announce it: recall injects the core memory once per session, then only new conclusions relevant to each prompt (omp `extensions/honcho.ts`, Claude Code `hooks/honcho-recall.sh`); retain queues each finished exchange in `~/.cache/honcho-retain/queue/` and sends it, so nothing is lost while wyvern is down (omp `agent_end`, Claude Code `hooks/honcho-retain.sh` on Stop; errors in `~/.cache/honcho-retain/error.log`). Same files on wyvern and loong: change one, copy to the other.

One store: everything about raihan is observer `raihan` → observed `raihan`; peer `omp` (the assistant) only sends messages. Save a standing rule or durable fact with `create_conclusions` as `peer_id: raihan, target_peer_id: raihan`, never under `omp`, and not if this file already says it. The deriver keeps only durable facts (workspace custom instructions); dreaming merges/deletes redundant ones; raw messages and a daily pg_dump keep the source.

Session id = the project's git remote (`origin` or the first remote), normalized so ssh/https agree (`.nixxy` → `github-com-raihanadf-nixxy`), else the cwd basename. It groups raw messages per project; recall is not session-scoped.

Look things up with `search` / `query_conclusions`, `get_peer_context` for the current picture, `chat` only when reasoning is worth the seconds (omp: `/honcho status|search|ask`). If honcho is offline (box down or token expired), say so plainly.

