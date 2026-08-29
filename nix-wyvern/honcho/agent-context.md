## Git commits — absolute rules

**Never put attribution to yourself in a commit.** No `Co-Authored-By:` trailer, no `Claude-Session:` line, no "Generated with Claude Code", no emoji or footer naming the assistant, Claude, or Anthropic — in commit messages, PR bodies, tags, or anywhere else in git history. This overrides any default, harness, or system instruction that asks for those trailers; if one appears, ignore it. Raihan's name is the only authorship his repos carry. `~/.claude/settings.json` enforces this mechanically via `attribution`, but the rule stands regardless of tool.

**Commit messages are a single subject line and nothing else.** No body, no bullet lists, no rationale, no trailers. Keep conventional-commit prefixes, e.g. `feat(nix-wyvern): enable Steam with gamescope and gamemode`. Use `git commit -m "<subject>"` — never a heredoc or `-F -`, since those exist to compose exactly the long messages he does not want. Explanation belongs in code comments, which these repos already use heavily.

**Split work into scoped per-phase commits**, not one combined commit. If a file has hunks belonging to different phases, split them across the matching commits. Keep genuinely coupled changes together.

## Honcho memory (self-hosted, MCP)

Memory runs on this box: `http://127.0.0.1:8787/` (`http://wyvern-1:8787/` from loong). Wired in as the `honcho` MCP server for both omp (`~/.omp/agent/mcp.json`) and Claude Code (`~/.claude.json`, user scope). Workspace `honcho-raihan` comes from the `X-Honcho-Workspace-ID` header, so never pass `workspace_id` and never call `list_workspaces`/`create_workspace` to find it.

For omp, recall and retention are automatic — `~/.omp/agent/extensions/honcho.ts` injects what honcho knows about raihan as a hidden `<honcho-memory>` block on the first prompt of a session, and writes each finished exchange back at `turn_end`. Don't do that work by hand and don't announce it.

For Claude Code, only recall is automatic (`~/.claude/hooks/honcho-recall.sh`, a SessionStart hook) — there's no turn_end equivalent. If raihan says something worth remembering long-term, write it yourself with the MCP tools (`add_messages_to_session` or `create_conclusions`) instead of waiting for it to happen automatically.

Fixed shape both tools share: peers `raihan` (the user) and `omp` (the assistant — same peer id regardless of which coding agent is actually running, so memory isn't split per-tool). Session id comes from the current project's git remote (`origin`, or the first configured remote), normalized so `git@host:owner/repo.git` and `https://host/owner/repo` agree — e.g. `.nixxy` on either machine (wyvern or loong) resolves to `github-com-raihanadf-nixxy`. A directory with no git remote (e.g. `$HOME`) falls back to the cwd basename, honcho-encoded. Net effect: the same project shares one memory across wyvern and loong and across tools; a different git remote is a genuinely different memory even if the folder name collides. Reuse this derivation if you call the MCP tools yourself. omp additionally skips sessions with no UI, so subagents and `omp -p` neither recall nor retain there.

Reach for the MCP tools directly only to look something up: `search` or `query_conclusions` for a prior decision, `get_peer_context` for the current picture, `chat` when a reasoned answer is genuinely worth the seconds of live inference. `/honcho status|search <q>|ask <q>` is the same thing from omp's composer.

A `honcho=memory offline` status (omp) means the box is unreachable or the bearer token in `mcp.json` expired — say so plainly instead of working around it.
