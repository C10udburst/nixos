/**
 * evo-x2-queue — a request-level lease on the shared EVO-X2 machine.
 *
 * The EVO-X2 box behind the gateway models is a single shared resource: the
 * gateway hands out time-boxed slots through its reservation API
 * (`/api/reservations` on the dashboard host). This extension turns every
 * provider request into a gate on that API:
 *
 *   /enqueue <allotment> [comment]  want a slot of this size; [comment] is the
 *                                   dashboard note (also the waitlist comment)
 *   /enqueue status                 show lease state and the machine state
 *   /dequeue                        give the slot back / stop wanting one
 *
 * The gate lives in `before_provider_request`, which pi awaits after building
 * the payload and before the HTTP call to /v1/chat/completions. When the
 * machine is not ours, the handler simply does not return: the request hangs
 * with no first token, exactly like a slow model would, and pi already handles
 * long TTFT everywhere — spinner, Esc-abort, queued steering and follow-ups
 * all keep working. Nothing is ever captured, replayed, or aborted: prompts
 * typed while the gate is closed sit in pi's own queues and reach the model
 * as later turns of the same run, strictly after the gate opened. Holding the
 * lease is what the gate checks per request; one valid lease covers the whole
 * run, so mid-run turns flow untouched while the slot is ours.
 *
 * Two policies keep the shared box friendly:
 *  - When the agent settles with nothing queued, the lease is released right
 *    away — idle minutes are not hoarded — while the gate stays armed, so a
 *    follow-up prompt re-queues and (the box usually still free) re-acquires
 *    it without any user action.
 *  - A request that reaches the gate with less than 10 minutes left on the
 *    lease extends it through POST /extend by the original allotment
 *    (halving the step while a collision 409 says the extra time would run
 *    into a scheduled slot), so long-running work rolls its slot forward
 *    instead of racing the expiry.
 *
 * The state machine per gate passage:
 *   1. check whether the machine is free,
 *   2. reserve it for the wanted allotment, stamping the comment,
 *   3. let the request through.
 * When the slot expires mid-run, the next turn's request re-enters the gate
 * and retakes it at the original allotment; if something else holds it, the
 * run simply waits. Waiting never spams the gateway: it sleeps
 * min(5m, 2/3 of the current holder's remaining time) between polls, and a
 * free machine that refuses the requested allotment (409 "Maximum available
 * time is Xm") is reserved at X - 5 minutes instead.
 *
 * Ownership is decided by the reservation rows this client creates: an active
 * row carrying one of those ids is ours even after the waitlist promoted it,
 * while a different client — or a different session behind the same egress IP
 * — reads as "someone else" even where the server's own `is_holder` flag
 * would disagree.
 *
 * Everything is gated on the current model actually being served from the
 * gateway domain, so sessions on other providers never block.
 *
 * Config (env, read at load time):
 *   EVO_X2_RESERVATIONS_URL   default https://evo-x2.brix0.wilkins.pl.eu.org
 *                             (the host serving /api/reservations)
 *   EVO_X2_QUEUE_DOMAIN       default "evo-x2"; a model is gated when its
 *                             baseUrl or provider contains this substring
 */

import type {
    ExtensionAPI,
    ExtensionCommandContext,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";

// ------------------------------------------------------------------ config

const API_BASE =
    (process.env.EVO_X2_RESERVATIONS_URL || "https://evo-x2.brix0.wilkins.pl.eu.org")
        .replace(/\/+$/, "") + "/api/reservations";
const GATEWAY_DOMAIN = (process.env.EVO_X2_QUEUE_DOMAIN || "evo-x2").toLowerCase();

const DEFAULT_MINUTES = 30;
const MIN_MINUTES = 1;
const MAX_MINUTES = 1440;
/** Reserve this much under the advertised maximum when the API shrinks a request. */
const COLLISION_SLACK_MINUTES = 5;
/** Below this a shrunk slot is not worth taking; wait the window out instead. */
const MIN_VIABLE_MINUTES = 5;
/** The API truncates notes at 256 characters. */
const MAX_NOTE = 240;

/** Bounds for "sleep min(5m, 2/3 of what is left), then poll again". */
const MIN_WAIT_MS = 30_000;
const MAX_WAIT_MS = 5 * 60_000;
/** A request reaching the gate with less than this left on the lease extends it. */
const EXTEND_HORIZON_MS = 10 * 60_000;
/** Debounce for extension attempts; the ladder of shrink-on-409 stops at 5m. */
const EXTEND_DEBOUNCE_MS = 30_000;
const EXTEND_MIN_MINUTES = 5;
/** Anything unreachable/unscheduled falls back to this pause. */
const FALLBACK_WAIT_MS = 60_000;
const API_TIMEOUT_MS = 15_000;

const STATUS_KEY = "evo-x2-queue";

// ------------------------------------------------------------------ types

interface ActiveReservation {
    id: number | string;
    client_name?: string;
    expires_at?: number | null;
    remaining_seconds?: number | null;
    duration_minutes?: number | null;
    note?: string;
}

interface QueueEntry {
    id: number | string;
    client_ip?: string;
    created_at?: number;
    note?: string;
}

interface ReservationState {
    client?: {
        ip?: string;
        name?: string;
        is_holder?: boolean;
        is_queued?: boolean;
        queue_position?: number | null;
    };
    active?: ActiveReservation | null;
    queue?: QueueEntry[];
    server_time?: number;
}

/** The slot we hold: server-side row id plus its computed expiry. */
interface Identity {
    id: number | string;
    expiresAtMs: number;
}

type ReserveOutcome =
    | { kind: "held" }
    | { kind: "retry"; retryMs: number; why: string };

class ApiError extends Error {
    status: number;
    constructor(status: number, message: string) {
        super(message);
        this.status = status;
    }
}

// ------------------------------------------------------------------ state

/** Did the user ask for a lease (/enqueue yes, /dequeue no)? */
let wantLease = false;
let note = "";
let wantedMinutes = DEFAULT_MINUTES;
/** Rows we inserted, queued or active; the anchor of ownership. */
let ourRows = new Set<number | string>();
let identity: Identity | undefined;
let giveUp = false;
let shuttingDown = false;
/** Single-flight: every gate caller awaits the same ensureLease pass. */
let leaseFlight: Promise<void> | undefined;

let lastCtx: ExtensionContext | undefined;

/** Fallback for the window before any event delivered a context. */
const NULL_CTX = {
    ui: {},
    isIdle: () => true,
    hasPendingMessages: () => false,
    abort: () => undefined,
} as unknown as ExtensionContext;

function liveCtx(): ExtensionContext {
    return lastCtx ?? NULL_CTX;
}

// ------------------------------------------------------------- reservations API

async function api<T = Record<string, unknown>>(
    path: string,
    body?: Record<string, unknown>,
): Promise<T> {
    let lastErr: unknown;
    // One retry for transport failures only; an answer from the server stands.
    for (let attempt = 0; attempt < 2; attempt++) {
        try {
            const response = await fetch(`${API_BASE}${path}`, {
                method: body ? "POST" : "GET",
                headers: { "content-type": "application/json", accept: "application/json" },
                ...(body ? { body: JSON.stringify(body) } : {}),
                signal: AbortSignal.timeout(API_TIMEOUT_MS),
            });
            const raw = await response.text();
            let json: Record<string, unknown> | undefined;
            try {
                json = raw ? (JSON.parse(raw) as Record<string, unknown>) : undefined;
            } catch {
                json = undefined;
            }
            if (!response.ok) {
                const detail =
                    typeof json?.error === "string" && json.error.trim()
                        ? json.error.trim()
                        : `HTTP ${response.status}`;
                throw new ApiError(response.status, detail);
            }
            return (json ?? {}) as T;
        } catch (err) {
            if (err instanceof ApiError) throw err;
            lastErr = err;
        }
    }
    throw lastErr instanceof Error ? lastErr : new Error(String(lastErr));
}

async function fetchState(): Promise<ReservationState | undefined> {
    try {
        return await api<ReservationState>("");
    } catch {
        return undefined;
    }
}

/**
 * POST /acquire with a time-boxed request carrying the comment as its note.
 *
 * - 200 acquired                   -> the slot is ours.
 * - 200 queued                     -> someone holds it; wait out their remainder.
 *   (the server has no already_active: even the holder's duplicate acquire
 *   joins the FIFO, so we only ever acquire when we saw the box free).
 * - 409 "Maximum available time is Xm" -> the box is free but a scheduled slot
 *   cuts the allotment short; retry once with X - 5 minutes (bounded recursion).
 */
async function reserve(minutes: number, depth = 0): Promise<ReserveOutcome> {
    try {
        const res = await api<{ status?: string; state?: ReservationState }>("/acquire", {
            mode: "timeboxed",
            duration: Math.round(minutes),
            note,
        });
        if (res.status === "acquired" || res.status === "already_active") {
            if (res.state?.active) {
                adopt(res.state.active);
                return { kind: "held" };
            }
            return { kind: "retry", retryMs: FALLBACK_WAIT_MS, why: "acquired, but the reply carried no active slot" };
        }
        // Our freshly inserted row is in the reply's waitlist: remembering it is
        // what makes its later promotion read as "ours" instead of "someone else".
        harvestRow(res.state);
        return { kind: "retry", retryMs: holderWaitMs(res.state?.active), why: "queued behind the current holder" };
    } catch (err) {
        if (err instanceof ApiError && err.status === 409) {
            const match = /Maximum available time is (\d+)m/i.exec(err.message);
            if (match) {
                const available = Number(match[1]);
                const viable = available - COLLISION_SLACK_MINUTES;
                if (viable >= MIN_VIABLE_MINUTES && depth < 4) return reserve(viable, depth + 1);
                return {
                    kind: "retry",
                    retryMs: clampWait((available * 60_000 * 2) / 3),
                    why: `a scheduled slot leaves only ${available}m`,
                };
            }
            return { kind: "retry", retryMs: FALLBACK_WAIT_MS, why: err.message };
        }
        return {
            kind: "retry",
            retryMs: FALLBACK_WAIT_MS,
            why: err instanceof Error ? err.message : String(err),
        };
    }
}

let lastExtendAttemptMs = 0;

/**
 * POST /extend — roll the active lease forward by the original allotment.
 * The API adds minutes to `max(now, expires_at)` of our own active timeboxed
 * row and answers 409 when the new horizon would overlap a scheduled slot;
 * the step is then halved (30m -> 15m -> 8m ...) down to a 5m floor. Any
 * other failure just leaves the current expiry standing for the next gate.
 */
async function tryExtend(): Promise<void> {
    if (Date.now() - lastExtendAttemptMs < EXTEND_DEBOUNCE_MS) return;
    lastExtendAttemptMs = Date.now();
    const base = Math.min(240, Math.max(EXTEND_MIN_MINUTES, wantedMinutes));
    for (let attempt = 0; attempt < 4; attempt++) {
        const minutes = Math.max(EXTEND_MIN_MINUTES, Math.floor(base / 2 ** attempt));
        try {
            const res = await api<{ status?: string; state?: ReservationState }>("/extend", { minutes });
            const act = res.state?.active;
            if (act && isOurs(act)) adopt(act);
            return;
        } catch (err) {
            if (err instanceof ApiError && err.status === 409 && minutes > EXTEND_MIN_MINUTES) continue;
            return;
        }
    }
}

async function releaseAndCancel(): Promise<void> {
    try {
        await api("/release", {});
    } catch {
        // The server expires the slot on its own.
    }
    try {
        await api("/cancel", {});
    } catch {
        // Nothing queued, or already gone.
    }
}

// ------------------------------------------------------------------ identity

function isOurs(active: ActiveReservation | null | undefined): boolean {
    if (!active) return false;
    if (identity && active.id === identity.id) return true;
    return ourRows.has(active.id);
}

/** Claim the newest of our rows that the reply's waitlist still carries. */
function harvestRow(state?: ReservationState): void {
    const ip = state?.client?.ip;
    if (!ip || !state?.queue) return;
    let newest: QueueEntry | undefined;
    for (const entry of state.queue) {
        if (entry.client_ip !== ip || ourRows.has(entry.id)) continue;
        if (!newest || (entry.created_at ?? 0) > (newest.created_at ?? 0)) newest = entry;
    }
    if (newest) ourRows.add(newest.id);
}

/** True while one of our rows still sits in the waitlist. */
function queuedByUs(state: ReservationState): boolean {
    return (state.queue ?? []).some((entry) => ourRows.has(entry.id));
}

function adopt(active: ActiveReservation): void {
    const expiresAtMs =
        typeof active.expires_at === "number"
            ? active.expires_at * 1000
            : Date.now() + wantedMinutes * 60_000;
    identity = { id: active.id, expiresAtMs };
    ourRows.add(active.id);
}

// ------------------------------------------------------------------ helpers

function onGateway(ctx: ExtensionContext): boolean {
    const model = ctx.model as
        | { baseUrl?: string; provider?: string; id?: string }
        | undefined;
    if (!model) return false;
    const haystack =
        `${model.baseUrl ?? ""} ${model.provider ?? ""} ${model.id ?? ""}`.toLowerCase();
    return haystack.includes(GATEWAY_DOMAIN);
}

function clampWait(ms: number): number {
    if (!Number.isFinite(ms)) return FALLBACK_WAIT_MS;
    return Math.min(Math.max(Math.round(ms), MIN_WAIT_MS), MAX_WAIT_MS);
}

function holderWaitMs(active?: ActiveReservation | null): number {
    const remaining = active?.remaining_seconds;
    if (typeof remaining !== "number" || remaining <= 0) return FALLBACK_WAIT_MS;
    return clampWait((remaining * 1000 * 2) / 3);
}

function clampMinutes(value: number): number {
    return Math.min(Math.max(Math.round(value), MIN_MINUTES), MAX_MINUTES);
}

/** "90", "45m", "1h", "1h30" -> minutes. */
function parseDurationToken(token: string): number | undefined {
    const t = token.toLowerCase().replace(/[,;:]$/, "");
    const combined = /^(\d+)h(\d+)?m?$/.exec(t);
    if (combined) return Number(combined[1]) * 60 + Number(combined[2] ?? 0);
    const single = /^(\d+(?:\.\d+)?)(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)?$/i.exec(t);
    if (!single) return undefined;
    const value = Number(single[1]);
    return single[2]?.[0] === "h" ? value * 60 : value;
}

/** Collapse to a single line that survives the API's note length cap. */
function oneLine(text: string): string {
    return text.replace(/\s+/g, " ").trim().slice(0, MAX_NOTE);
}

function formatDuration(seconds?: number | null): string {
    if (typeof seconds !== "number" || seconds <= 0) return "unknown time";
    const mins = Math.round(seconds / 60);
    if (mins < 60) return `${mins}m`;
    return `${Math.floor(mins / 60)}h${String(mins % 60).padStart(2, "0")}`;
}

function formatRemaining(expiresAtMs?: number): string {
    if (!expiresAtMs) return "unknown";
    return formatDuration(Math.max(0, (expiresAtMs - Date.now()) / 1000));
}

/** Sleep that wake() cuts short; pass an abort signal so Esc cancels the gate. */
function nap(ms: number, signal?: AbortSignal): Promise<void> {
    const clamped = Math.max(1_000, Math.floor(ms));
    return new Promise((resolve) => {
        const finish = () => {
            clearTimeout(timer);
            wakeFn = undefined;
            signal?.removeEventListener("abort", finish);
            resolve();
        };
        const timer = setTimeout(finish, clamped);
        if (typeof (timer as { unref?: () => void }).unref === "function") {
            (timer as { unref: () => void }).unref();
        }
        wakeFn = finish;
        signal?.addEventListener("abort", finish, { once: true });
    });
}

let wakeFn: (() => void) | undefined;

function wake(): void {
    const fn = wakeFn;
    wakeFn = undefined;
    if (fn) fn();
}

function status(text: string | undefined): void {
    try {
        lastCtx?.ui.setStatus?.(STATUS_KEY, text);
    } catch {
        // UI may be gone during shutdown.
    }
}

function say(text: string, level: "info" | "warning" | "error" = "info"): void {
    try {
        lastCtx?.ui.notify?.(`evo-x2: ${text}`, level);
    } catch {
        // UI may be gone during shutdown.
    }
}

// ------------------------------------------------------------------ the gate

/**
 * Block until a lease is held. Returns early (letting the request through
 * unreserved) when the lease was given up, the session is going away, or the
 * caller's run was aborted with Esc — in those cases pi owns what happens to
 * the request, not us.
 */
async function ensureLease(signal?: AbortSignal): Promise<void> {
    while (wantLease && !giveUp && !shuttingDown && !signal?.aborted) {
        const state = await fetchState();
        if (!state) {
            status("evo-x2: reservations API unreachable — retrying");
            await nap(FALLBACK_WAIT_MS, signal);
            continue;
        }
        if (isOurs(state.active)) {
            adopt(state.active!);
            if (identity && identity.expiresAtMs - Date.now() < EXTEND_HORIZON_MS) {
                await tryExtend();
                if (!identity || identity.expiresAtMs <= Date.now()) continue;
            }
            status(`evo-x2: lease ours for ${formatRemaining(identity?.expiresAtMs)} — /dequeue to release`);
            return;
        }
        if (!state.active && !queuedByUs(state)) {
            const outcome = await reserve(wantedMinutes);
            if (outcome.kind === "held") {
                status(`evo-x2: lease ours for ${formatRemaining(identity?.expiresAtMs)} — /dequeue to release`);
                return;
            }
            status(`evo-x2: waiting — ${outcome.why}`);
            await nap(outcome.retryMs, signal);
            continue;
        }
        if (!state.active) {
            // Our row is the only thing standing between us and the machine;
            // the server promotes it on its next read.
            status("evo-x2: next in line");
            await nap(MIN_WAIT_MS, signal);
            continue;
        }
        status(
            `evo-x2: held by ${state.active.client_name ?? "another client"} (${formatDuration(state.active.remaining_seconds)} left)`,
        );
        await nap(holderWaitMs(state.active), signal);
    }
}

/** Shared by every provider request and the eager /enqueue acquire. */
function leaseGate(signal?: AbortSignal): Promise<void> {
    if (!wantLease || giveUp) return Promise.resolve();
    if (identity && identity.expiresAtMs - Date.now() > EXTEND_HORIZON_MS) return Promise.resolve();
    if (!leaseFlight) {
        leaseFlight = ensureLease(signal).finally(() => {
            leaseFlight = undefined;
        });
    }
    return leaseFlight;
}

// ------------------------------------------------------------------ extension

export default function (pi: ExtensionAPI): void {
    pi.on("session_start", async (_event, ctx) => {
        // Reload/new session: no lease wanted, and any previous wait is gone;
        // a server-side slot (if one was still held) expires on its own.
        wantLease = false;
        giveUp = false;
        shuttingDown = false;
        note = "";
        wantedMinutes = DEFAULT_MINUTES;
        ourRows = new Set();
        identity = undefined;
        leaseFlight = undefined;
        lastCtx = ctx;
        status(undefined);
    });

    // Awaited so the release lands before the process goes away.
    pi.on("session_shutdown", async () => {
        shuttingDown = true;
        wake();
        if (identity || ourRows.size) await releaseAndCancel();
    });

    // The gate. Awaits before the /v1/chat/completions (or other provider)
    // request goes out: while the lease is not ours, the run simply waits with
    // no first token, and pi's own queueing keeps collecting everything typed.
    pi.on("before_provider_request", async (_event, ctx) => {
        lastCtx = ctx;
        if (!wantLease || giveUp || !onGateway(ctx)) return undefined;
        await leaseGate(ctx.signal);
        return undefined;
    });

    // The machine is shared hardware: hand the slot back as soon as the
    // agent is done with it. The gate stays armed, so a follow-up prompt
    // simply re-queues and — the box usually still free — re-acquires it.
    pi.on("agent_settled", async (_event, ctx) => {
        lastCtx = ctx;
        if (!wantLease || giveUp || !identity) return;
        if (ctx.hasPendingMessages?.()) return; // queued steer/follow-ups mean work remains
        const left = formatRemaining(identity.expiresAtMs);
        identity = undefined;
        ourRows.clear();
        await releaseAndCancel();
        status("evo-x2: idle — released; the next request will re-queue");
        say(`work settled with ${left} left — released the machine; next request re-queues`);
    });

    pi.on("model_select", async (event, ctx) => {
        lastCtx = ctx;
        if (!wantLease) return;
        const switched = {
            baseUrl: event.model?.baseUrl,
            provider: event.model?.provider,
            id: event.model?.id,
        } as ExtensionContext["model"];
        if (!onGateway({ ...ctx, model: switched } as ExtensionContext)) {
            say(`model left the "${GATEWAY_DOMAIN}" gateway; the lease gate stays closed for it until you /dequeue and re-arm`, "warning");
        }
    });

    pi.registerCommand("enqueue", {
        description: "Request an EVO-X2 lease; provider requests pause until it is held (usage: /enqueue 45m rebasing the flake)",
        getArgumentCompletions: (prefix: string) => {
            const needle = (prefix ?? "").trimStart().split(/\s+/)[0] ?? "";
            if (!needle && !prefix) return null;
            const options = ["15m", "30m", "1h", "2h", "4h", "status"]
                .filter((value) => value.startsWith(needle))
                .map((value) => ({ value, label: value }));
            return options.length > 0 ? options : null;
        },
        handler: async (args: string, ctx: ExtensionCommandContext) => {
            lastCtx = ctx;
            const text = (args ?? "").trim();
            if (!text) {
                say("usage: /enqueue <allotment> [comment] — e.g. /enqueue 45m rebasing the flake");
                return;
            }
            if (text === "status") {
                const lines: string[] = [];
                lines.push(`gate: ${wantLease ? (giveUp ? "given up" : "armed") : "disarmed (no /enqueue this session)"}`);
                if (note) lines.push(`comment: ${note}`);
                if (identity) lines.push(`lease: ours, expires in ${formatRemaining(identity.expiresAtMs)}`);
                const state = await fetchState();
                const position = state?.client?.queue_position;
                if (position) lines.push(`queue position: ${position}`);
                if (state?.active && !isOurs(state.active)) {
                    lines.push(`machine: ${state.active.client_name ?? "another client"} for ${formatDuration(state.active.remaining_seconds)}`);
                } else if (state && !state.active) {
                    lines.push("machine: free");
                }
                ctx.ui.notify?.(`evo-x2 queue\n${lines.join("\n")}`, "info");
                return;
            }

            const first = text.split(/\s+/)[0];
            const minutes = parseDurationToken(first);
            if (minutes === undefined) {
                say("usage: /enqueue <allotment> [comment] — allotment is 90, 45m, 1h or 1h30", "warning");
                return;
            }
            const comment = oneLine(text.slice(first.length));

            if (!onGateway(ctx)) {
                say(`current model is not served from "${GATEWAY_DOMAIN}" — no reservation needed`, "warning");
                return;
            }

            wantedMinutes = clampMinutes(minutes);
            if (comment) note = comment;
            if (!wantLease) note ||= "pi reservation";
            const wasArmed = wantLease && !giveUp;
            wantLease = true;
            giveUp = false;
            say(`lease armed for ${formatDuration(wantedMinutes * 60)} — requests pause until the machine is ours`);
            // Eagerly chase the slot so the first prompt does not wait; later
            // requests join the same flight, and the gate is the authority.
            if (!wasArmed || !leaseFlight) {
                void leaseGate().catch(() => undefined);
            }
        },
    });

    pi.registerCommand("dequeue", {
        description: "Release an EVO-X2 lease and stop gating requests on it",
        handler: async (_args: string, ctx: ExtensionCommandContext) => {
            lastCtx = ctx;
            const wasHeld = !!identity;
            const hadState = wasHeld || ourRows.size > 0;
            wantLease = false;
            giveUp = true;
            identity = undefined;
            wake(); // unblock any in-flight gate: it lets requests through
            status(undefined);
            // Requests in flight are let through unreserved (pi's run continues);
            // only talk to the server when we actually have a row there.
            if (hadState) await releaseAndCancel();
            ourRows.clear();
            say(wasHeld ? "released the machine" : "lease disarmed");
        },
    });
}
