You never execute any "git" command at all (e.g an intent to git commit/push yourself). Never do a git commit or git push yourself. I am the one who does that. And if I want you to do that, I will explicitly tell you to do so. And never mention your name in commit detail.

Write code comments in all lowercase

Write everything (code and functions) human-coded. No overcomplex or overengineered code like multiple functions just for a simple one task. a task thats simple shouldnt have more than 2 functions, depending on how complex it is.

Never use fully-qualified class names inline (e.g. \App\Models\User::). Always add a use import at the top of the file and reference the short class name instead.

Never run tests (php artisan test, phpunit, pest, etc.) unless I explicitly ask. `RefreshDatabase` can wipe real data if phpunit.xml lacks a test DB override. Write test files when asked, but do not execute them.


## Core Architecture & Conventions
* **Thin Handlers:** Entry points (Controllers/Handlers) must only manage routing, request parsing, and response formatting. Extract business rules into dedicated Service, Action, or Use Case modules.
* **Strict Validation:** Validate incoming data at the boundary using dedicated schemas, Structs, or DTOs. Never validate inline unless for a single, trivial field.
* **Decoupled Responses:** Use Presenters or Serializers to format data. Never return raw database records or internal models to avoid leaking schema or internal state.
* **Explicit Routing:** Use type-safe, direct references for route mapping. Never use string-based routing or magic reflection.
* **Strict Data Access:** Optimize data fetching (e.g., eager loading) to prevent N+1 issues. Do not rely on implicit lazy loading, and strictly respect allowed mutation fields.
* **Idiomatic Naming:** Match the target language's community standards for casing (e.g., `camelCase` vs `snake_case`), directory structure, and handlers (e.g., `UserHandler`).

For any file search or grep in the current git-indexed directory, use fff tools.

No silent fallbacks — if data is missing or null, let it fail visibly; never use `|| default` or `?? default` to paper over missing data (exception: explicit user-facing 'N/A' text display only).

## Branch workflow

Merges go one way only: `feature/*` → `development`, then `feature/*` → `staging`, → `preprod`, → `release/release`. Sandbox branches are never merged back into the feature branch, so the feature branch must merge cleanly into all of them with no intermediate resolve.

Git conflicts on region overlap against the merge-base. If a sandbox branch already rewrote a method and the feature branch also edits that method, every fan-out merge conflicts — extracting helpers or shrinking the diff will not avoid it. Keep such regions byte-identical to the merge-base and put the fix somewhere uncontested instead.

Before finishing work that touches a shared file:
1. `git ls-tree origin/<branch> -- <file>` across the sandboxes — identical blobs mean one target text.
2. `git show $(git merge-base HEAD origin/development):<file>` — if the sandbox version differs from the merge-base, that region was rewritten downstream. Do not touch it.
3. Verify without mutating anything: `TMPC=$(git stash create)` then `git merge-tree --write-tree --name-only "$TMPC" origin/<branch>` per branch. No refs move, working tree untouched.

## Honcho memory (self-hosted, MCP)

Memory runs on wyvern: `http://wyvern:8787/` (`127.0.0.1:8787` on wyvern), the `honcho` MCP server in `~/.omp/agent/mcp.json` and `~/.claude.json`. Workspace comes from the `X-Honcho-Workspace-ID` header: never pass `workspace_id`, never list/create workspaces.

Automatic in both tools, never do it by hand or announce it: recall injects the core memory once per session, then only new conclusions relevant to each prompt (omp `extensions/honcho.ts`, Claude Code `hooks/honcho-recall.sh`); retain queues each finished exchange in `~/.cache/honcho-retain/queue/` and sends it, so nothing is lost while wyvern is down (omp `agent_end`, Claude Code `hooks/honcho-retain.sh` on Stop; errors in `~/.cache/honcho-retain/error.log`). Same files on wyvern and loong: change one, copy to the other.

One store: everything about raihan is observer `raihan` → observed `raihan`; peer `omp` (the assistant) only sends messages. Save a standing rule or durable fact with `create_conclusions` as `peer_id: raihan, target_peer_id: raihan`, never under `omp`, and not if this file already says it. The deriver keeps only durable facts (workspace custom instructions); dreaming merges/deletes redundant ones; raw messages and a daily pg_dump keep the source.

Session id = the project's git remote (`origin` or the first remote), normalized so ssh/https agree (`.nixxy` → `github-com-raihanadf-nixxy`), else the cwd basename. It groups raw messages per project; recall is not session-scoped.

Look things up with `search` / `query_conclusions`, `get_peer_context` for the current picture, `chat` only when reasoning is worth the seconds (omp: `/honcho status|search|ask`). If honcho is offline (box down or token expired), say so plainly.

Episode log (`~/tools/mem/mem.ts`, `mem` on PATH, both machines): every agent run (prompt, each tool call with args, clipped results, replies; secrets redacted) is one message from peer `log` in the honcho session `<project>--log` (reasoning and summaries off, so the deriver never sees it). Captured at the same omp `agent_end` / Claude Code Stop, queued in `~/.cache/honcho-retain/episodes/`, sent ledger `episodes.sent`. The `mem-compact` user service on wyvern (`tencent/hy3` via the OpenRouter key in the honcho `.env`) writes each episode as one line and merges pairs into a binary tree, UniiChat-style; the project's view (~24 KB, recent runs one line each, older ones merged) is injected once per session as `<memory-log>`. Before guessing about past work, `mem zoom -p <project> <id+n>` opens a line into its halves, `mem zoom -p <project> <id>` gives the full episode, `mem search "<query>"` searches every project. `mem import` backfills this machine's transcripts (already done for both on 2026-10-20).

@RTK.md

## Dump page

When I say "dump it/this" (or ask to show something on my phone), upload it with the `dump` CLI: `dump <file>` for images, .md or .txt files, `dump -m "markdown"` for inline markdown, or pipe text into `dump` (`dump -m` for markdown). It shows on https://remote.iblameraihan.com (Dump page, only the newest 30 are kept). `dump get [n]` reads back what I dumped from my phone (1 = newest). Run `dump` without args for usage.

## InsightAccess

Rules live in `~/tools/ia/AGENT-RULES.md`, linked as `~/Projects/InsightAccess/CLAUDE.md` and `AGENTS.md`, so Claude Code and omp load them only under `~/Projects/InsightAccess/`.
