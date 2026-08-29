// honcho memory wiring: recalls context at session start, records each turn at turn end.
// talks straight to the honcho mcp endpoint declared in ~/.omp/agent/mcp.json, so the
// url, bearer token and workspace header live in exactly one place.
import { execSync } from "node:child_process";
import { basename } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const MCP_CONFIG = `${process.env.HOME}/.omp/agent/mcp.json`;
const USER_PEER = "raihan";
const AGENT_PEER = "omp";

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
			{ peer_id: USER_PEER, observe_me: true, observe_others: true },
			{ peer_id: AGENT_PEER, observe_me: false, observe_others: true },
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

// the prompt that opened this turn and the reply that closed it
function lastExchange(entries: readonly { type: string; message?: { role?: string; content?: unknown } }[]) {
	let user = "";
	let assistant = "";
	for (const entry of entries) {
		if (entry.type !== "message") continue;
		const role = entry.message?.role;
		if (role === "user") {
			user = messageText(entry.message?.content);
			assistant = "";
		} else if (role === "assistant") {
			const text = messageText(entry.message?.content);
			if (text) assistant = text;
		}
	}
	return { user, assistant };
}

export default function honcho(pi: ExtensionAPI) {
	let lastWritten = "";
	pi.setLabel("Honcho Memory");
	pi.logger?.debug?.(`honcho extension loaded, endpoint from ${MCP_CONFIG}`);

	// pull what honcho knows and hand it to the model with the first prompt of the session
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		try {
			const id = honchoSessionId(ctx.cwd);
			await ensureSession(id);
			const context = JSON.parse(await call("get_peer_context", { peer_id: USER_PEER, session_id: id }));
			// a cold peer answers with an empty representation and no card; injecting that is pure noise
			const known = [context.representation?.trim(), context.peer_card].filter(Boolean).join("\n");
			if (!known) {
				ctx.ui.setStatus("honcho", "memory empty");
				return;
			}
			pi.sendMessage(
				{
					customType: "honcho.recall",
					content: `<honcho-memory session="${id}">\n${known}\n</honcho-memory>`,
					display: false,
					attribution: "user",
				},
				{ deliverAs: "nextTurn" },
			);
			ctx.ui.setStatus("honcho", "memory loaded");
		} catch (error) {
			pi.logger?.error?.(`honcho recall failed: ${String(error)}`);
			ctx.ui.setStatus("honcho", "memory offline");
		}
	});

	// record the finished exchange; subagents and print mode have no ui and are skipped
	pi.on("turn_end", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		const { user, assistant } = lastExchange(ctx.sessionManager.getBranch() as never);
		if (!user || !assistant) return;
		const fingerprint = `${user}\u0000${assistant}`;
		if (fingerprint === lastWritten) return;
		try {
			const id = honchoSessionId(ctx.cwd);
			await ensureSession(id);
			await call("add_messages_to_session", {
				session_id: id,
				messages: [
					{ peer_id: USER_PEER, content: user },
					{ peer_id: AGENT_PEER, content: assistant },
				],
			});
			lastWritten = fingerprint;
		} catch (error) {
			pi.logger?.error?.(`honcho retain failed: ${String(error)}`);
			ctx.ui.setStatus("honcho", "retain failed");
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
					ctx.ui.notify(
						await call("chat", { peer_id: AGENT_PEER, target_peer_id: USER_PEER, session_id: id, query }),
						"info",
					);
					return;
				}
				throw new Error(`unknown subcommand "${verb}"`);
			} catch (error) {
				ctx.ui.notify(`honcho: ${String(error)}`, "error");
			}
		},
	});
}
