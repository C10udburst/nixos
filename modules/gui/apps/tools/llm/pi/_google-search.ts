/**
 * google-search — let the model query the googleaisearch2api gateway.
 *
 * One model-facing tool, nothing else (no commands, no TUI):
 *   google_search  live web search returning a grounded answer plus source URLs
 *
 * The gateway is deployed on brix0 as `google-ai-proxy`, a Sablier-suspended web app behind
 * Caddy, so it is normally scaled to zero. The first request through the edge wakes the
 * container and answers with a progress page instead of JSON; this extension pokes through
 * that wake-up itself and only reports failure once the wake budget is spent.
 *
 * Config (env, re-read on every call):
 *   GOOGLE_SEARCH_API_BASE       default http://127.0.0.1:9010 (loopback of the host running
 *                                the gateway; the NixOS pi module points it at the https edge)
 *   GOOGLE_SEARCH_API_TOKEN      Bearer token. Only needed when the gateway itself sets API_TOKEN;
 *                                an empty gateway API_TOKEN means no auth header is sent.
 *   GOOGLE_SEARCH_API_MODEL      omitted from the request unless set, so the gateway uses its own
 *                                DEFAULT_MODEL (a name it does not know is a 404).
 *   GOOGLE_SEARCH_API_TIMEOUT_MS default 120000, per HTTP attempt
 *   GOOGLE_SEARCH_API_WAKE_MS    default 90000, total budget for a cold (suspended) gateway
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ------------------------------------------------------------------ config

const DEFAULT_BASE = "http://127.0.0.1:9010";
const DEFAULT_TIMEOUT_MS = 120_000;
const MIN_TIMEOUT_MS = 5_000;
const MAX_TIMEOUT_MS = 600_000;
const DEFAULT_WAKE_MS = 90_000;
const MIN_WAKE_MS = 0;
const MAX_WAKE_MS = 600_000;
const MAX_ANSWER_CHARS = 8_000;

/** Poll interval while the edge brings a suspended gateway back up. */
const WAKE_POLL_MS = 5_000;
/** Nothing is listening at all (no proxy in front), so do not wait long for it to appear. */
const COLD_BUDGET_MS = 15_000;
const COLD_POLL_MS = 3_000;
/** A running gateway said it is busy; one short retry is cheap, more just wastes the call. */
const BUSY_DELAY_MS = 5_000;
const MAX_BUSY_RETRIES = 1;

function delayFor(retry: Retry): number {
    switch (retry) {
        case "wake":
            return WAKE_POLL_MS;
        case "cold":
            return COLD_POLL_MS;
        case "busy":
            return BUSY_DELAY_MS;
    }
}

function budgetFor(retry: Retry, wakeMs: number): number {
    switch (retry) {
        case "cold":
            return COLD_BUDGET_MS;
        // Bounded by MAX_BUSY_RETRIES instead: the gateway is up and answering.
        case "busy":
            return Number.POSITIVE_INFINITY;
        case "wake":
            return wakeMs;
    }
}

/** Why a failed call is worth repeating. */
type Retry =
    /** Reached the edge, not the API: Sablier progress page, connection-reset error page. */
    | "wake"
    /** No HTTP answer at all; the container may still be starting. */
    | "cold"
    /** The API answered 429/503 with JSON; it is up but has no free worker. */
    | "busy";

const WAKE_HINT =
    "the gateway is suspended behind its reverse proxy and did not come back in time: " +
    "open its URL in a browser to watch the wake-up page, or raise GOOGLE_SEARCH_API_WAKE_MS.";

const UNREACHABLE_HINT =
    "nothing answered at this base. Run the gateway (or `systemctl start podman-google-ai-proxy.service` " +
    "on its host), or point GOOGLE_SEARCH_API_BASE at a running one.";

const STATUS_HINTS: Record<number, string> = {
    401: "the gateway demands a Bearer token: set GOOGLE_SEARCH_API_TOKEN and restart Pi.",
    403: "the gateway refused this token: check GOOGLE_SEARCH_API_TOKEN against its API_TOKEN.",
    404: "the gateway does not know this model name: unset GOOGLE_SEARCH_API_MODEL or match its DEFAULT_MODEL.",
    422: "the gateway rejected the payload: reword or shorten the query.",
    429: "upstream rate limit: wait ~30s, then retry once with a reworded query.",
    502: "upstream refused the answer (quality gate or blocked exit): reword the query.",
    503: "gateway busy or engine not ready: retry shortly.",
    504: "upstream timed out: ask for less in one call.",
};

interface Config {
    base: string;
    token: string;
    model: string;
    timeoutMs: number;
    wakeMs: number;
}

function envNumber(name: string, fallback: number, min: number, max: number): number {
    const raw = Number(process.env[name] || fallback);
    const value = Number.isFinite(raw) ? Math.round(raw) : fallback;
    return Math.min(Math.max(value, min), max);
}

function config(): Config {
    return {
        base: (process.env.GOOGLE_SEARCH_API_BASE || DEFAULT_BASE).replace(/\/+$/, ""),
        token: (process.env.GOOGLE_SEARCH_API_TOKEN || "").trim(),
        model: (process.env.GOOGLE_SEARCH_API_MODEL || "").trim(),
        timeoutMs: envNumber("GOOGLE_SEARCH_API_TIMEOUT_MS", DEFAULT_TIMEOUT_MS, MIN_TIMEOUT_MS, MAX_TIMEOUT_MS),
        wakeMs: envNumber("GOOGLE_SEARCH_API_WAKE_MS", DEFAULT_WAKE_MS, MIN_WAKE_MS, MAX_WAKE_MS),
    };
}

// ---------------------------------------------------------------- transport

interface Source {
    title: string;
    url: string;
    snippet?: string;
}

type Outcome =
    | { ok: true; answer: string; sources: Source[]; status: number; durationMs: number }
    | { ok: false; error: string; status?: number; retry?: Retry; durationMs: number };

interface QueryBody {
    query: string;
    instructions?: string;
}

/** A wake-up page or an edge error page is HTML; the API always answers with a JSON object. */
function isWakePage(status: number, json: Record<string, unknown> | undefined): boolean {
    if (json) return false;
    return status >= 500 || status === 429 || status < 400;
}

/** POST /query once, mapping every failure mode to text the model can act on. */
async function postOnce(
    cfg: Config,
    body: QueryBody,
    signal: AbortSignal | undefined,
): Promise<Outcome> {
    const started = Date.now();
    // The gateway does its own retries, so a single call can run for a minute or more.
    const timeout = AbortSignal.timeout(cfg.timeoutMs);
    const active = signal ? AbortSignal.any([signal, timeout]) : timeout;

    const payload: Record<string, unknown> = {
        query: body.query,
        instructions: body.instructions,
        include_citations: true,
        include_google_metadata: false,
    };
    if (cfg.model) payload.model = cfg.model;

    let response: Response;
    try {
        response = await fetch(`${cfg.base}/query`, {
            method: "POST",
            headers: {
                "content-type": "application/json",
                ...(cfg.token ? { authorization: `Bearer ${cfg.token}` } : {}),
            },
            body: JSON.stringify(payload),
            signal: active,
        });
    } catch (err) {
        if (signal?.aborted) return { ok: false, error: "cancelled", durationMs: Date.now() - started };
        if (timeout.aborted) {
            return {
                ok: false,
                error: sentences(
                    `no answer from ${cfg.base} within ${Math.round(cfg.timeoutMs / 1000)}s`,
                    "Raise GOOGLE_SEARCH_API_TIMEOUT_MS or narrow the query",
                ),
                durationMs: Date.now() - started,
            };
        }
        return {
            ok: false,
            error: sentences(`${describeFetchError(err)} (${cfg.base})`, UNREACHABLE_HINT),
            retry: "cold",
            durationMs: Date.now() - started,
        };
    }

    const raw = await response.text();
    const json = parseObject(raw);

    if (!response.ok) {
        if (isWakePage(response.status, json)) {
            // Either the Sablier progress page or the proxy's own error page: something at the
            // edge answered, the API did not. Name the final URL so a login page is not mistaken
            // for a wake-up page.
            const where = response.redirected ? `${cfg.base} -> ${response.url}` : cfg.base;
            return {
                ok: false,
                error: `HTTP ${response.status} with a non-JSON page from ${where}`,
                status: response.status,
                retry: "wake",
                durationMs: Date.now() - started,
            };
        }
        const detail = typeof json?.detail === "string" && json.detail.trim()
            ? json.detail.trim()
            : raw.slice(0, 300).replace(/\s+/g, " ").trim() || response.statusText;
        const hint = STATUS_HINTS[response.status];
        return {
            ok: false,
            error: sentences(`HTTP ${response.status}: ${detail}`, hint),
            status: response.status,
            retry: response.status === 429 || response.status === 503 ? "busy" : undefined,
            durationMs: Date.now() - started,
        };
    }

    if (!json) {
        return {
            ok: false,
            error: `the gateway replied with non-JSON (${cfg.base})`,
            status: response.status,
            retry: "wake",
            durationMs: Date.now() - started,
        };
    }

    const answer = typeof json.answer === "string" ? json.answer.trim() : "";
    if (!answer) {
        return {
            ok: false,
            error: "the gateway returned an empty answer. Reword the query.",
            status: response.status,
            durationMs: Date.now() - started,
        };
    }

    return {
        ok: true,
        answer,
        sources: parseSources(json.citations),
        status: response.status,
        durationMs: Date.now() - started,
    };
}

/**
 * POST /query, waiting out a suspended gateway.
 *
 * Every attempt is a fresh request through the edge, which is exactly what keeps the wake-up
 * going, so the loop simply re-asks until the API itself answers or the budget runs out.
 */
async function postQuery(
    cfg: Config,
    body: QueryBody,
    signal: AbortSignal | undefined,
): Promise<Outcome> {
    const started = Date.now();
    let attempts = 1;
    let busyRetries = 0;
    let outcome = await postOnce(cfg, body, signal);

    while (!outcome.ok && outcome.retry && !signal?.aborted) {
        if (outcome.retry === "busy") {
            if (busyRetries >= MAX_BUSY_RETRIES) break;
            busyRetries += 1;
        }
        const delay = delayFor(outcome.retry);
        if (Date.now() - started + delay > budgetFor(outcome.retry, cfg.wakeMs)) break;
        await sleep(delay, signal);
        if (signal?.aborted) break;
        attempts += 1;
        outcome = await postOnce(cfg, body, signal);
    }

    if (outcome.ok) return outcome;
    if (signal?.aborted) return { ok: false, error: "cancelled", status: outcome.status, durationMs: Date.now() - started };

    const notes: string[] = [];
    const waited = Date.now() - started;
    if (attempts > 1) {
        notes.push(`gave up after ${attempts} attempts${waited >= 1000 ? ` and ${(waited / 1000).toFixed(1)}s` : ""}`);
    }
    if (outcome.retry === "wake") notes.push(WAKE_HINT);
    if (outcome.retry === "busy") notes.push("still busy after the retry: try again in a minute");
    return { ...outcome, error: sentences(outcome.error, ...notes) };
}

/** Join report fragments without stacking punctuation. */
function sentences(...parts: (string | undefined)[]): string {
    return parts
        .filter((part): part is string => !!part)
        .map((part) => part.replace(/\s+$/, "").replace(/[.;]+$/, ""))
        .join(". ") + ".";
}

function describeFetchError(err: unknown): string {
    if (err instanceof Error) {
        const cause = err.cause as { code?: string; message?: string } | undefined;
        const detail = cause?.code || cause?.message || err.message;
        return `connection failed: ${detail}`;
    }
    return `connection failed: ${String(err)}`;
}

function sleep(ms: number, signal: AbortSignal | undefined): Promise<void> {
    return new Promise((resolve) => {
        const timer = setTimeout(done, ms);
        signal?.addEventListener("abort", done, { once: true });
        function done() {
            clearTimeout(timer);
            resolve();
        }
    });
}

function parseObject(raw: string): Record<string, unknown> | undefined {
    try {
        const value = JSON.parse(raw) as unknown;
        return value && typeof value === "object" && !Array.isArray(value)
            ? (value as Record<string, unknown>)
            : undefined;
    } catch {
        return undefined;
    }
}

function parseSources(citations: unknown): Source[] {
    if (!Array.isArray(citations)) return [];
    const sources: Source[] = [];
    for (const item of citations) {
        if (!item || typeof item !== "object") continue;
        const rec = item as Record<string, unknown>;
        const url = typeof rec.url === "string" ? rec.url.trim() : "";
        if (!url) continue;
        const title = typeof rec.title === "string" && rec.title.trim() ? rec.title.trim() : hostOf(url);
        const snippet = typeof rec.snippet === "string" ? rec.snippet.trim() : "";
        sources.push({ title, url, ...(snippet ? { snippet } : {}) });
    }
    return sources;
}

function hostOf(url: string): string {
    try {
        return new URL(url).hostname.replace(/^www\./, "");
    } catch {
        return url;
    }
}

// ------------------------------------------------------------ text shaping

function formatAnswer(answer: string, sources: Source[]): string {
    const text = answer.length > MAX_ANSWER_CHARS
        ? `${answer.slice(0, MAX_ANSWER_CHARS)}\n\n[truncated: ${answer.length} chars total]`
        : answer;
    if (!sources.length) return text;
    const list = sources.map((s, i) => `${i + 1}. ${s.title} — ${s.url}`).join("\n");
    return `${text}\n\nSources:\n${list}`;
}

// ------------------------------------------------------------------ schemas

const SourceSchema = Type.Object({
    title: Type.String(),
    url: Type.String(),
    snippet: Type.Optional(Type.String()),
});

const SearchOutput = Type.Object({
    query: Type.String(),
    answer: Type.String(),
    sources: Type.Array(SourceSchema),
    error: Type.Optional(Type.String()),
});

const SearchParams = Type.Object({
    query: Type.String({
        description: "Natural-language question or topic. Full questions work better than keyword strings.",
    }),
    instructions: Type.Optional(
        Type.String({
            description: 'Optional extra steering, e.g. "focus on Python 3.13 behaviour" or "answer in Chinese".',
        }),
    ),
});

const readOnly = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true };

// --------------------------------------------------------------------- tool

export default function (pi: ExtensionAPI) {
    pi.registerTool({
        name: "google_search",
        label: "Google Search",
        description:
            "Search the live web through a Google AI search gateway. Returns a synthesized, " +
            "current answer plus source URLs. Use it for anything the training data cannot answer: " +
            "recent news, release notes, library/API versions, prices, dates, or when you must cite sources.",
        promptSnippet: "Live web search with a grounded answer and source URLs (Google-backed).",
        promptGuidelines: [
            "google_search returns an answer, not a raw results list; the Sources block lists citable URLs.",
            "When you need several distinct sources or dates, ask for them in the query (\"list the five most recent X, with dates\").",
            "Ask it as a complete question. Do not pass site: operators or date ranges, they degrade results.",
            "The gateway may be suspended: the tool already waits for it to wake, so a slow first call is normal.",
            "It fails when the upstream engine rate-limits or the answer quality gate rejects; retry once with a reworded query before giving up.",
            "A connection error means nothing is listening at the gateway URL — that is not a query problem; do not retry the same call.",
        ],
        parameters: SearchParams,
        outputSchema: SearchOutput,
        annotations: readOnly,

        async execute(_id, params, signal, _onUpdate, _ctx) {
            const outcome = await postQuery(config(), params, signal);

            if (!outcome.ok) {
                return {
                    content: [{ type: "text", text: `google_search failed: ${outcome.error}` }],
                    isError: true,
                    structuredContent: { query: params.query, answer: "", sources: [], error: outcome.error },
                    details: { query: params.query, status: outcome.status, duration_ms: outcome.durationMs, error: outcome.error },
                };
            }

            return {
                content: [{ type: "text", text: formatAnswer(outcome.answer, outcome.sources) }],
                structuredContent: { query: params.query, answer: outcome.answer, sources: outcome.sources },
                details: {
                    query: params.query,
                    status: outcome.status,
                    duration_ms: outcome.durationMs,
                    answer_chars: outcome.answer.length,
                    sources: outcome.sources,
                },
            };
        },
    });

}
