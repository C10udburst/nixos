/**
 * evo-x2-queue — /enqueue: a time-boxed lease on the shared EVO-X2 machine.
 *
 * The EVO-X2 box behind the gateway models is a single shared resource: the
 * gateway hands out time-boxed slots through its reservation API
 * (`/api/reservations` on the dashboard host). This extension makes pi a
 * polite citizen of that queue:
 *
 *   /enqueue <allotment> [note]  reserve the machine; [note] is the comment
 *   /enqueue status              show the phase, queue and slot remaining
 *   /dequeue                     give up a pending wait or release a held slot
 *
 * A reservation is a lease, not a prompt. `/enqueue 45m rebasing the flake`
 * stamps "rebasing the flake" as the reservation note — the comment the
 * dashboard shows next to the active slot and the waitlist entry — and nothing
 * is ever injected into the model. Once the slot is ours the session is simply
 * handed back: the next message typed is the prompt, running on the machine we
 * just reserved.
 *
 * The state machine:
 *   1. check whether the machine is free,
 *   2. reserve it for the requested allotment, stamping the note,
 *   3. hold it. Prompts typed while still waiting are held back and delivered as
 *      user messages the moment the slot becomes ours; from then on input goes
 *      through untouched,
 *   4. after every finalized message (assistant reply or tool result), ask the
 *      API whether the slot is still ours; if it expired or someone else holds
 *      it, execution is aborted and the cycle starts again — re-reserving with
 *      the original allotment.
 *
 * The slot behaves like a semaphore: an idle agent does not give it back. The
 * lease ends with /dequeue, with the session, or with its expiry.
 *
 * Waiting is designed not to spam a busy gateway: when the machine is held by
 * someone else the extension waits min(5m, 2/3 of that holder's remaining time)
 * before asking again. When the machine is free but refuses the requested
 * allotment (a scheduled slot would cut it short, answered as HTTP 409 with
 * "Maximum available time is Xm"), it reserves the advertised maximum minus
 * five minutes instead.
 *
 * Ownership is decided by the reservation rows this client creates: an active
 * row carrying one of those ids is ours even after the waitlist promoted it,
 * while a different client — or a different pi session behind the same egress
 * IP — reads as "someone else" even where the server's own `is_holder` flag
 * would disagree.
 *
 * All of this is gated on the current model actually being served from the
 * gateway domain, so sessions on other providers are untouched.
 *
 * Config (env, read at load time):
 *   EVO_X2_RESERVATIONS_URL   default https://evo-x2.brix0.wilkins.pl.eu.org
 *                             (the host serving /api/reservations)
 *   EVO_X2_QUEUE_DOMAIN       default "evo-x2.brix0.wilkins.pl.eu.org"; a model
 *                             participates in the queue when its baseUrl or
 *                             provider contains this
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
/** Below this a shrunk slot is not worth starting a run for; wait it out instead. */
const MIN_VIABLE_MINUTES = 5;
/** The API truncates notes at 256 characters. */
const MAX_NOTE = 240;

/** "wait min(5m, 2/3 of what is left, then ask again)" bounds. */
const MIN_WAIT_MS = 30_000;
const MAX_WAIT_MS = 5 * 60_000;
/** Ownership checks ride on finalized messages; this throttles fast tool loops. */
const MIN_CHECK_MS = 15_000;
/** Slack after a slot's expiry before the timer-driven ownership re-check. */
const EXPIRY_GRACE_MS = 5_000;
const API_TIMEOUT_MS = 15_000;
/** Anything unreachable/unscheduled falls back to this pause. */
const FALLBACK_WAIT_MS = 60_000;

const STATUS_KEY = "evo-x2-queue";

// ------------------------------------------------------------------ types

interface ActiveReservation {
    id: number | string;
    client_name?: string;
    mode?: string;
    duration_minutes?: number | null;
    expires_at?: number | null;
    remaining_seconds?: number | null;
    note?: string;
}

interface QueueEntry {
    id: number | string;
    client_ip?: string;
    client_name?: string;
    mode?: string;
    duration_minutes?: number | null;
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
        queue_positions?: number[];
    };
    active?: ActiveReservation | null;
    queue?: QueueEntry[];
    server_time?: number;
}

/** Identity of the slot we hold: the server-side row id plus its expiry. */
interface Identity {
    id: number | string;
    expiresAtMs: number;
}

type Phase = "idle" | "waiting" | "running";

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

let phase: Phase = "idle";
/** Interactive prompts typed while the machine wait blocks execution. */
let pending: string[] = [];
/** The comment stamped on the reservation, set by /enqueue. */
let note = "";
/** The allotment /enqueue asked for; lost slots are retaken at this size. */
let originalMinutes = DEFAULT_MINUTES;
/** Every reservation row this client inserted, queued or active. */
let ourRows = new Set<number | string>();
let identity: Identity | undefined;
let preempted = false;
let giveUp = false;
let shuttingDown = false;
let lastOwnershipCheck = 0;
let wakeFn: (() => void) | undefined;

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
 * POST /acquire with a time-boxed request carrying the note as its comment.
 *
 * - 200 acquired / already_active  -> the slot is ours.
 * - 200 queued                     -> someone holds it; wait out 2/3 of their remainder.
 * - 409 "Maximum available time is Xm" -> the box is free but a scheduled slot
 *   cuts our allotment short; retry once with X - 5 minutes (bounded recursion).
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

/** The rows we inserted. Ids are unique, so no other client can match one. */
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
            : Date.now() + (active.duration_minutes ?? originalMinutes) * 60_000;
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

/** Sleep that event handlers can cut short via wake(). */
function waitOrWake(ms: number): Promise<void> {
    const clamped = Math.max(1_000, Math.floor(ms));
    return new Promise((resolve) => {
        const finish = () => {
            clearTimeout(timer);
            wakeFn = undefined;
            resolve();
        };
        const timer = setTimeout(finish, clamped);
        if (typeof (timer as { unref?: () => void }).unref === "function") {
            (timer as { unref: () => void }).unref();
        }
        wakeFn = () => {
            clearTimeout(timer);
            wakeFn = undefined;
            resolve();
        };
    });
}

function wake(): void {
    const fn = wakeFn;
    wakeFn = undefined;
    if (fn) fn();
}

function status(ctx: ExtensionContext, text: string | undefined): void {
    try {
        ctx.ui.setStatus?.(STATUS_KEY, text);
    } catch {
        // UI may be gone during shutdown.
    }
}

function holdingStatus(ctx: ExtensionContext): void {
    status(
        ctx,
        `evo-x2: ours for ${formatRemaining(identity?.expiresAtMs)} — /dequeue to release`,
    );
}

function say(ctx: ExtensionContext, text: string, level: "info" | "warning" | "error" = "info"): void {
    try {
        ctx.ui.notify?.(`evo-x2: ${text}`, level);
    } catch {
        // UI may be gone during shutdown.
    }
}

// ------------------------------------------------------------------ delivery

/** Replay prompts that were held back during the wait, as if just typed. */
async function deliver(pi: ExtensionAPI, ctx: ExtensionContext, texts: string[]): Promise<void> {
    const failed: string[] = [];
    for (const text of texts) {
        try {
            if (ctx.isIdle()) {
                await pi.sendUserMessage(text);
            } else {
                await pi.sendUserMessage(text, { deliverAs: "followUp" });
            }
        } catch {
            failed.push(text);
        }
    }
    if (failed.length) {
        pending.unshift(...failed);
        say(ctx, `${failed.length} held message(s) could not be delivered; they will be retried`, "warning");
    }
}

// ------------------------------------------------------------------ supervisor

/**
 * The state machine: idle -> waiting (blocked) -> running (lease held) -> idle.
 *
 * Awaited by the /enqueue command handler that started it, so the command
 * context stays valid for the whole reservation lifetime. The session is usable
 * throughout: while waiting, typed prompts are collected by the input handler;
 * while the lease is held they pass straight through to the model.
 */
async function supervisor(pi: ExtensionAPI, ctx: ExtensionCommandContext): Promise<void> {
    try {
        while (!shuttingDown && !giveUp) {
            // ---- 1-2: execution blocked; wait for the machine and reserve it.
            phase = "waiting";
            let held = false;
            while (!held && !shuttingDown && !giveUp) {
                const state = await fetchState();
                if (!state) {
                    status(ctx, "evo-x2: reservations API unreachable");
                    await waitOrWake(FALLBACK_WAIT_MS);
                    continue;
                }
                if (isOurs(state.active)) {
                    adopt(state.active!);
                    held = true;
                    break;
                }
                if (!state.active && !queuedByUs(state)) {
                    const outcome = await reserve(originalMinutes);
                    if (outcome.kind === "held") {
                        held = true;
                        break;
                    }
                    status(ctx, `evo-x2: waiting — ${outcome.why}`);
                    await waitOrWake(outcome.retryMs);
                    continue;
                }
                if (!state.active) {
                    // Our row is the only thing standing between us and the
                    // machine; the server promotes it on its next read.
                    status(ctx, "evo-x2: next in line");
                    await waitOrWake(MIN_WAIT_MS);
                    continue;
                }
                status(
                    ctx,
                    `evo-x2: held by ${state.active.client_name ?? "another client"} (${formatDuration(state.active.remaining_seconds)} left)`,
                );
                await waitOrWake(holderWaitMs(state.active));
            }
            if (shuttingDown || giveUp) break;

            // ---- 3: the machine is ours. Nothing is injected as a prompt — the
            // user's next message is the prompt — but anything typed during the
            // wait fires now.
            phase = "running";
            preempted = false;
            lastOwnershipCheck = Date.now();
            holdingStatus(ctx);
            if (pending.length) {
                await deliver(pi, ctx, pending.splice(0, pending.length));
            }

            // ---- 4: hold the lease. Wakes on a message-triggered preempt, on
            // /dequeue or shutdown, or at the slot's expiry (+grace) at the latest.
            let lost = false;
            while (!shuttingDown && !giveUp) {
                const dueMs = (identity?.expiresAtMs ?? Date.now() + FALLBACK_WAIT_MS) + EXPIRY_GRACE_MS;
                await waitOrWake(dueMs - Date.now());
                if (shuttingDown || giveUp) break;
                if (preempted) {
                    preempted = false;
                    lost = true;
                    break;
                }

                const state = await fetchState();
                if (!state) {
                    await waitOrWake(FALLBACK_WAIT_MS);
                    continue;
                }
                if (isOurs(state.active)) {
                    adopt(state.active!);
                    holdingStatus(ctx);
                    continue;
                }
                if (!state.active) {
                    // Our slot expired with nobody promoted ahead: retake it at
                    // the original allotment without interrupting the session.
                    const outcome = await reserve(originalMinutes);
                    if (outcome.kind === "held") continue;
                    status(ctx, `evo-x2: re-reserving — ${outcome.why}`);
                }
                // Occupied by something else: block execution and go back to waiting.
                lost = true;
                try {
                    ctx.abort();
                } catch {
                    // The run may already be finishing on its own.
                }
                break;
            }
            if (shuttingDown || giveUp) break;
            if (lost) {
                identity = undefined;
                say(ctx, "lost the machine — requeueing; it will be retaken at the original allotment", "warning");
            }
        }
    } finally {
        // Leaving for good: hand the machine back and drop the waitlist row.
        const wasHeld = !!identity;
        phase = "idle";
        identity = undefined;
        ourRows.clear();
        status(ctx, undefined);
        await releaseAndCancel();
        if (giveUp) {
            say(ctx, wasHeld ? "released the machine" : "gave up the wait");
        }
    }
}

// ------------------------------------------------------------------ extension

export default function (pi: ExtensionAPI): void {
    pi.on("session_start", () => {
        // Reload/new session: the previous supervisor is gone; the server-side
        // slot (if any) expires on its own.
        shuttingDown = false;
        giveUp = false;
        phase = "idle";
        pending = [];
        note = "";
        ourRows = new Set();
        identity = undefined;
        preempted = false;
    });

    pi.on("session_shutdown", () => {
        shuttingDown = true;
        wake();
    });

    // While the machine wait blocks execution, typed prompts are collected
    // instead of starting runs. Our own injected prompts and slash commands
    // always pass through.
    pi.on("input", async (event, ctx) => {
        if (phase !== "waiting") return undefined;
        if (event.source !== "interactive") return undefined;
        if (event.text.trimStart().startsWith("/")) return undefined;
        if (!onGateway(ctx)) return undefined;
        pending.push(event.text);
        say(ctx, `held until the machine is ours (${pending.length} pending)`);
        return { action: "handled" } as const;
    });

    // Every finalized assistant reply and tool result is a cheap moment to ask
    // whether the machine is still ours, throttled so fast tool loops do not
    // hammer the gateway.
    pi.on("message_end", async (event, ctx) => {
        if (phase !== "running") return;
        const role = (event.message as { role?: string } | undefined)?.role;
        if (role !== "assistant" && role !== "toolResult") return;
        if (Date.now() - lastOwnershipCheck < MIN_CHECK_MS) return;
        lastOwnershipCheck = Date.now();

        const state = await fetchState();
        if (!state) return;
        if (isOurs(state.active)) {
            adopt(state.active!);
            return;
        }
        preempted = true;
        try {
            ctx.abort();
        } catch {
            // Already settling.
        }
        wake();
    });

    pi.on("model_select", async (event, ctx) => {
        if (phase === "idle") return;
        const switched = {
            baseUrl: event.model?.baseUrl,
            provider: event.model?.provider,
            id: event.model?.id,
        } as ExtensionContext["model"];
        if (!onGateway({ ...ctx, model: switched } as ExtensionContext)) {
            say(ctx, `model left the "${GATEWAY_DOMAIN}" gateway while ${phase}; /dequeue to drop the reservation`, "warning");
        }
    });

    pi.registerCommand("enqueue", {
        description: "Reserve the EVO-X2 machine; the text becomes the queue comment (usage: /enqueue 45m rebasing the flake)",
        getArgumentCompletions: (prefix: string) => {
            const needle = (prefix ?? "").trimStart().split(/\s+/)[0] ?? "";
            if (!needle && !prefix) return null;
            const options = ["15m", "30m", "1h", "2h", "4h", "status"]
                .filter((value) => value.startsWith(needle))
                .map((value) => ({ value, label: value }));
            return options.length > 0 ? options : null;
        },
        handler: async (args: string, ctx: ExtensionCommandContext) => {
            const text = (args ?? "").trim();
            if (!text) {
                say(ctx, "usage: /enqueue <allotment> [comment] — e.g. /enqueue 45m rebasing the flake");
                return;
            }
            if (text === "status") {
                const lines = [`phase: ${phase}`];
                if (note) lines.push(`comment: ${note}`);
                if (identity) lines.push(`slot: ours, expires in ${formatRemaining(identity.expiresAtMs)}`);
                if (pending.length) lines.push(`messages held from the wait: ${pending.length}`);
                const state = await fetchState();
                const position = state?.client?.queue_position;
                if (position) lines.push(`queue position: ${position}`);
                if (state?.active && !isOurs(state.active)) {
                    lines.push(`machine: ${state.active.client_name ?? "another client"} for ${formatDuration(state.active.remaining_seconds)}`);
                } else if (state && !state.active && phase === "idle") {
                    lines.push("machine: free");
                }
                ctx.ui.notify?.(`evo-x2 queue\n${lines.join("\n")}`, "info");
                return;
            }

            const first = text.split(/\s+/)[0];
            const minutes = parseDurationToken(first);
            if (minutes === undefined) {
                say(ctx, "usage: /enqueue <allotment> [comment] — allotment is 90, 45m, 1h or 1h30", "warning");
                return;
            }
            const comment = oneLine(text.slice(first.length));

            // Off-gateway models need no reservation.
            if (!onGateway(ctx)) {
                say(ctx, `current model is not served from "${GATEWAY_DOMAIN}" — no reservation needed`, "warning");
                return;
            }

            // Already waiting or holding: the lease was requested once, and the
            // machine takes the prompt whenever it arrives.
            if (phase === "waiting") {
                if (comment) note = comment;
                say(ctx, `already waiting for the machine (${formatDuration(minutes * 60)} requested)`);
                return;
            }
            if (phase === "running" && identity) {
                say(ctx, `the machine is ours for ${formatRemaining(identity.expiresAtMs)} — just type your prompt`);
                return;
            }

            note = comment || "pi reservation";
            originalMinutes = clampMinutes(minutes);
            giveUp = false;
            await supervisor(pi, ctx);
        },
    });

    pi.registerCommand("dequeue", {
        description: "Give up a pending EVO-X2 wait, or release a held slot",
        handler: async (_args: string, ctx: ExtensionCommandContext) => {
            const dropped = pending.length;
            pending.length = 0;

            if (phase === "idle") {
                await releaseAndCancel();
                identity = undefined;
                ourRows.clear();
                status(ctx, undefined);
                say(ctx, "no reservation held");
                return;
            }

            // The supervisor sees the flag, releases the slot (or cancels the
            // waitlist row) and reports what it gave up.
            giveUp = true;
            if (!ctx.isIdle()) {
                say(ctx, "releasing the reservation while a run is in flight", "warning");
            } else if (dropped) {
                say(ctx, `dropped ${dropped} held message(s)`);
            }
            wake();
        },
    });
}
