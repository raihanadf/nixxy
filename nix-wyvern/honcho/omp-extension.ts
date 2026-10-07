// honcho memory wiring: recalls what honcho knows before each prompt, records each finished
// prompt at agent end. talks straight to the honcho mcp endpoint declared in
// ~/.omp/agent/mcp.json, so the url, bearer token and workspace header live in exactly one place.
// claude code does the same through ~/.claude/hooks/honcho-{recall,retain}.sh; both tools share
// the retain queue below, so an exchange written while wyvern is down is sent later, not lost.
import { execSync } from "node:child_process";
import { mkdirSync, readFileSync, readdirSync, rmSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const MCP_CONFIG = `${process.env.HOME}/.omp/agent/mcp.json`;
const USER_PEER = "raihan";
const AGENT_PEER = "omp";
const QUEUE = `${process.env.HOME}/.cache/honcho-retain/queue`;

let server: { url: string; headers: Record<string, string> } | undefined;

async function loadServer() {
	if (server) return server;
	const cfg = await Bun.file(MCP_CONFIG).json();
	const entry = cfg.mcpServers?.honcho;
	if (!entry?.url) throw new Error(`no honcho server in ${MCP_CONFIG}`);
	server = { url: entry.url, headers: entry.headers ?? {} };
	return server;
}

// one stateless json-rpc round trip; the server needs no initialize handshake per call
async function call(name: string, args: Record<string, unknown>): Promise<string> {
	const { url, headers } = await loadServer();
	const res = await fetch(url, {
		method: "POST",
		headers: { ...headers, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
		body: JSON.stringify({ jsonrpc: "2.0", id: Date.now(), method: "tools/call", params: { name, arguments: args } }),
		signal: AbortSignal.timeout(15_000),
	});
	const raw = await res.text();
	if (!res.ok) throw new Error(`${name}: http ${res.status} ${raw.slice(0, 200)}`);
	const frame = raw.split("\n").find((line) => line.startsWith("data: "));
	const payload = JSON.parse(frame ? frame.slice(6) : raw);
	if (payload.error) throw new Error(`${name}: ${payload.error.message}`);
	const text = payload.result?.content?.map((part: { text?: string }) => part.text ?? "").join("\n") ?? "";
	if (payload.result?.isError) throw new Error(`${name}: ${text.slice(0, 200)}`);
	return text;
}

const ready = new Set<string>();

// get-or-create the session bucket and its two peers, once per session id per process
async function ensureSession(sessionId: string) {
	if (ready.has(sessionId)) return;
	await call("create_session", { session_id: sessionId });
	await call("add_peers_to_session", {
		session_id: sessionId,
		peers: [
			{ peer_id: USER_PEER, observe_me: true, observe_others: false },
			{ peer_id: AGENT_PEER, observe_me: false, observe_others: false },
		],
	});
	ready.add(sessionId);
}

// honcho only accepts [a-zA-Z0-9_-]; a dotfile-style project dir like ".nixxy"
// or a "host/owner/repo" git identity both need this
function encodeId(raw: string): string {
	return raw.replace(/^[^a-zA-Z0-9]+/, "").replace(/[^a-zA-Z0-9_-]/g, "-");
}

// The same project should share one memory across clones, machines, and
// branches (wyvern and loong are both my own laptops); unrelated projects
// that happen to share a directory name should not. Key off the git remote
// (origin, or the first configured remote) when one exists -- normalized so
// git@host:owner/repo.git and https://host/owner/repo agree -- and only fall
// back to the cwd basename for non-git directories (e.g. $HOME itself).
function gitRemoteId(cwd: string): string | undefined {
	const opts = { cwd, stdio: ["ignore", "pipe", "ignore"] } as const;
	try {
		let url = execSync("git remote get-url origin", opts).toString().trim();
		if (!url) {
			const first = execSync("git remote", opts).toString().trim().split("\n")[0];
			if (!first) return undefined;
			url = execSync(`git remote get-url ${first}`, opts).toString().trim();
		}
		if (!url) return undefined;
		url = url.replace(/\.git$/, "");
		if (url.startsWith("git@")) return url.slice(4).replace(":", "/");
		if (url.startsWith("ssh://")) return url.slice(6).replace(/^git@/, "");
		if (url.startsWith("https://") || url.startsWith("http://")) return url.replace(/^https?:\/\//, "");
		return url;
	} catch {
		return undefined;
	}
}

function honchoSessionId(cwd: string): string {
	const id = encodeId(gitRemoteId(cwd) ?? basename(cwd));
	if (!id) throw new Error(`cannot derive a honcho session id from cwd "${cwd}"`);
	return id;
}

function messageText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((part) => part?.type === "text" && typeof part.text === "string")
		.map((part) => part.text)
		.join("\n")
		.trim();
}

// "[2026-10-07 18:08:25] text" -> "[2026-10-07] text": the time of day is noise for the model
function conclusionLines(representation: string | undefined): string[] {
	return (representation ?? "")
		.split("\n")
		.filter((line) => line.startsWith("["))
		.map((line) => line.replace(/^\[(\d{4}-\d{2}-\d{2}) [\d:]+\]/, "[$1]"));
}

// honcho caps a message at 25000 chars; a long paste becomes several messages, not a rejected one
function parts(peerId: string, text: string) {
	const out = [];
	for (let i = 0; i < text.length; i += 24_000) out.push({ peer_id: peerId, content: text.slice(i, i + 24_000) });
	return out;
}

// the prompt that opened this agent run and the final reply that closed it
function lastExchange(messages: readonly { role?: string; content?: unknown }[]) {
	let user = "";
	let assistant = "";
	for (const message of messages) {
		if (message.role === "user") {
			user = messageText(message.content);
			assistant = "";
		} else if (message.role === "assistant") {
			const text = messageText(message.content);
			if (text) assistant = text;
		}
	}
	return { user, assistant };
}

// send every queued exchange oldest first; stop at the first failure so order is kept.
// a mkdir lock keeps two sessions (or omp and claude code) from sending the same file twice.
async function drainQueue() {
	const lock = `${QUEUE}/.lock`;
	try {
		mkdirSync(lock);
	} catch {
		if (Date.now() - statSync(lock).mtimeMs < 120_000) return;
		rmSync(lock, { recursive: true, force: true });
		mkdirSync(lock);
	}
	try {
		for (const file of readdirSync(QUEUE).filter((f) => f.endsWith(".json")).sort()) {
			const payload = JSON.parse(readFileSync(`${QUEUE}/${file}`, "utf8"));
			await ensureSession(payload.session_id);
			try {
				await call("add_messages_to_session", payload);
			} catch (error) {
				// the session may have been deleted on the server; set it up again next time
				ready.delete(payload.session_id);
				throw error;
			}
			unlinkSync(`${QUEUE}/${file}`);
		}
	} finally {
		rmSync(lock, { recursive: true, force: true });
	}
}

export default function honcho(pi: ExtensionAPI) {
	let lastWritten = "";
	pi.setLabel("Honcho Memory");
	pi.logger?.debug?.(`honcho extension loaded, endpoint from ${MCP_CONFIG}`);

	// conclusions this session already carries in its context. the session start sends the core
	// memory once; each later prompt only adds conclusions relevant to it that are not in here yet.
	// the messages persist in the session (append only), so the prompt cache prefix stays valid.
	let seen = new Set<string>();
	let primed = false;
	const reset = () => {
		seen = new Set();
		primed = false;
	};
	for (const event of ["session_start", "session_switch", "session_branch", "session_tree", "session_compact"] as const) {
		pi.on(event, async () => reset());
	}

	pi.on("before_agent_start", async (event, ctx) => {
		if (!ctx.hasUI) return;
		try {
			const args = primed
				? { peer_id: USER_PEER, search_query: event.prompt.slice(0, 500), max_conclusions: 8 }
				: { peer_id: USER_PEER, max_conclusions: 40 };
			const context = JSON.parse(await call("get_peer_context", args));
			const lines = conclusionLines(context.representation).filter((line) => !seen.has(line));
			const card = primed ? "" : [context.peer_card].flat().filter(Boolean).join("\n");
			primed = true;
			ctx.ui.setStatus("honcho", "◇ mem");
			if (!lines.length && !card) return;
			for (const line of lines) seen.add(line);
			return {
				message: {
					customType: "honcho-memory",
					content: `<honcho-memory>\n${[card, ...lines].filter(Boolean).join("\n")}\n</honcho-memory>`,
					display: false,
				},
			};
		} catch (error) {
			pi.logger?.error?.(`honcho recall failed: ${String(error)}`);
			ctx.ui.setStatus("honcho", "× mem");
		}
	});

	// record the finished prompt once per agent run (turn_end would also catch mid-run narration).
	// it goes to the queue file first, so a crash or an unreachable wyvern never drops it.
	// subagents and print mode have no ui and are skipped.
	pi.on("agent_end", async (event, ctx) => {
		if (!ctx.hasUI || event.willContinue) return;
		const { user, assistant } = lastExchange(event.messages as never);
		if (!user || !assistant) return;
		const fingerprint = `${user}\u0000${assistant}`;
		if (fingerprint === lastWritten) return;
		lastWritten = fingerprint;
		try {
			const payload = {
				session_id: honchoSessionId(ctx.cwd),
				messages: [...parts(USER_PEER, user), ...parts(AGENT_PEER, assistant)],
			};
			mkdirSync(QUEUE, { recursive: true });
			const name = `${Math.floor(Date.now() / 1000)}-omp-${process.pid}-${Math.random().toString(36).slice(2, 8)}.json`;
			writeFileSync(`${QUEUE}/${name}`, JSON.stringify(payload));
			await drainQueue();
		} catch (error) {
			pi.logger?.error?.(`honcho retain failed (kept in ${QUEUE}): ${String(error)}`);
			ctx.ui.setStatus("honcho", "! retain queued");
		}
	});

	pi.registerCommand("honcho", {
		description: "honcho memory: status | search <query> | ask <question>",
		handler: async (args, ctx) => {
			const [verb, ...rest] = args.trim().split(/\s+/);
			const query = rest.join(" ");
			const id = honchoSessionId(ctx.cwd);
			try {
				if (!verb || verb === "status") {
					const state = await call("inspect_workspace", {});
					ctx.ui.notify(`honcho session "${id}" — ${state}`, "info");
					return;
				}
				if (verb === "search") {
					if (!query) throw new Error("search needs a query");
					ctx.ui.notify(await call("search", { query, peer_id: USER_PEER }), "info");
					return;
				}
				if (verb === "ask") {
					if (!query) throw new Error("ask needs a question");
					ctx.ui.notify(await call("chat", { peer_id: USER_PEER, query }), "info");
					return;
				}
				throw new Error(`unknown subcommand "${verb}"`);
			} catch (error) {
				ctx.ui.notify(`honcho: ${String(error)}`, "error");
			}
		},
	});
}
