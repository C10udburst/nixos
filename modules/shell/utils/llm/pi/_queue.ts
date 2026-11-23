/**
 * evo-x2-queue — /enqueue: time-boxed reservations for the shared EVO-X2 machine.
 *
 * The EVO-X2 box behind the gateway models is a single shared resource: the
 * gateway hands out time-boxed slots through its reservation API
 * (`/api/reservations` on the dashboard host). This extension makes pi a
 * polite citizen of that queue:
 *
 *   /enqueue <allotment> <message>   defer <message> until the machine is ours
 *   /enqueue status                  show the phase, queue and slot remaining
 *   /dequeue                         drop pending messages and give up/release
 *
 * After /enqueue the run is blocked (typed prompts are collected, not
 * executed) while the extension:
 *   1. checks whether the machine is free,
 *   2. reserves it for the requested allotment,
 *   3. resumes the agent by delivering the collected prompts as user messages,
 *   4. after every finalized message (assistant reply or tool result), asks the
 *      API whether the slot is still ours; if it expired or someone else holds
 *      it, execution is aborted and the cycle starts again — re-reserving with
 *      the original allotment.
 *
 * Waiting is designed not to spam a busy gateway: when the machine is held by
 * someone else the extension waits 2/3 of that holder's remaining time before
 * asking again. When the machine is free but refuses the requested allotment
 * (a scheduled slot would cut it short, answered as HTTP 409 with
 * "Maximum available time is Xm"), it reserves the advertised maximum minus
 * five minutes instead. If the agent finishes early — and only once there are
 * no follow-up messages left in pi's own queue — the lock is released early
 * rather than left to burn an idle machine.
 *
 * Ownership is decided by comparing the reservation `note` we stamp at acquire
 * time against the currently active reservation, not by IP: a different client
 * — or a different pi session behind the same egress IP — reads as "someone
 * else" even where the server's own `is_holder` flag would disagree.
 *
 * All of this is gated on the current model actually being served from the
 * gateway domain, so sessions on other providers are untouched.
 *
 * Config (env, read at load time):
 *   EVO_X2_RESERVATIONS_URL   default https://evo-x2.brix0.wilkins.pl.eu.org
 *                             (the host serving /api/reservations)
 *   EVO_X2_QUEUE_DOMAIN       default "evo-x2"; a model participates in the
 *                             queue when its baseUrl/provider contains this
 */

import { randomUUID } from "node:crypto";
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

/** Bounds for "wait 2/3 of what's left, then ask again". */
const MIN_WAIT_MS = 30_000;
const MAX_WAIT_MS = 20 * 60_000;
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

interface ReservationState {
    client?: { name?: string; is_holder?: boolean; is_queued?: boolean };
    active?: ActiveReservation | null;
    queue?: unknown[];
    server_time?: number;
}

interface QueuedMessage {
    text: string;
    minutes: number;
}

/** Identity of the slot we hold: server-side row id plus the note we stamped. */
interface Identity {
    id: number | string;
    note: string;
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
let queue: QueuedMessage[] = [];
/** The allotment the first /enqueue asked for; lost slots are retaken at this size. */
let originalMinutes = DEFAULT_MINUTES;
/** Unique note stamped on our acquire; the ownership comparison anchor. */
let reservationNote = "";
let identity: Identity | undefined;
let settled = false;
let preempted = false;
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
 * POST /acquire with a time-boxed request.
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
            note: reservationNote,
        });
        if (res.status === "acquired" || res.status === "already_active") {
            if (res.state?.active) {
                adopt(res.state.active);
                return { kind: "held" };
            }
            return { kind: "retry", retryMs: FALLBACK_WAIT_MS, why: "acquired, but the reply carried no active slot" };
        }
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

function isOurs(active: ActiveReservation | null | undefined): boolean {
    if (!identity || !active) return false;
    if (active.id === identity.id) return true;
    return !!active.note && active.note === identity.note;
}

function adopt(active: ActiveReservation): void {
    const expiresAtMs =
        typeof active.expires_at === "number"
            ? active.expires_at * 1000
            : Date.now() + (active.duration_minutes ?? originalMinutes) * 60_000;
    identity = { id: active.id, note: active.note ?? reservationNote, expiresAtMs };
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

function say(ctx: ExtensionContext, text: string, level: "info" | "warning" | "error" = "info"): void {
    try {
        ctx.ui.notify?.(`evo-x2: ${text}`, level);
    } catch {
        // UI may be gone during shutdown.
    }
}

// ------------------------------------------------------------------ delivery

/** Hand collected prompts to the agent as if they had just been typed. */
async function deliver(pi: ExtensionAPI, ctx: ExtensionContext, items: QueuedMessage[]): Promise<void> {
    const failed: QueuedMessage[] = [];
    for (const item of items) {
        try {
            if (ctx.isIdle()) {
                await pi.sendUserMessage(item.text);
            } else {
                await pi.sendUserMessage(item.text, { deliverAs: "followUp" });
            }
        } catch {
            failed.push(item);
        }
    }
    if (failed.length) {
        queue.push(...failed);
        say(ctx, `${failed.length} queued message(s) could not be delivered; they will be retried`, "warning");
    }
}

// ------------------------------------------------------------------ supervisor

/**
 * The state machine: idle -> waiting (blocked) -> running (held) -> idle.
 *
 * Awaited by the /enqueue command handler that started it, so the command
 * context stays valid for the whole reservation lifetime. Later /enqueue and
 * /dequeue invocations only mutate the queue and wake this loop.
 */
async function supervisor(pi: ExtensionAPI, ctx: ExtensionCommandContext): Promise<void> {
    reservationNote = `pi ${randomUUID().slice(0, 8)}`;
    originalMinutes = clampMinutes(queue[0]?.minutes ?? DEFAULT_MINUTES);

    try {
        while (!shuttingDown) {
            if (queue.length === 0) {
                await finish(ctx, false);
                return;
            }

            // ---- 0-2: execution blocked; wait for the machine and reserve it.
            phase = "waiting";
            let held = false;
            while (!held && !shuttingDown) {
                if (queue.length === 0) {
                    await finish(ctx, false);
                    return;
                }
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
                if (!state.active) {
                    const outcome = await reserve(originalMinutes);
                    if (outcome.kind === "held") {
                        held = true;
                        break;
                    }
                    status(ctx, `evo-x2: waiting — ${outcome.why}`);
                    await waitOrWake(outcome.retryMs);
                    continue;
                }
                status(
                    ctx,
                    `evo-x2: held by ${state.active.client_name ?? "another client"} (${formatDuration(state.active.remaining_seconds)} left)`,
                );
                await waitOrWake(holderWaitMs(state.active));
            }
            if (shuttingDown) break;

            // ---- 3: the machine is ours; resume the agent with the collected prompts.
            phase = "running";
            settled = false;
            preempted = false;
            lastOwnershipCheck = Date.now();
            status(ctx, `evo-x2: ours for ${formatRemaining(identity?.expiresAtMs)}`);
            await deliver(pi, ctx, queue.splice(0, queue.length));

            // ---- 4: supervise. Wakes on agent_settled, on a message-triggered
            // preempt, or at the slot's expiry (+grace) at the latest.
            while (!shuttingDown) {
                settled = false;
                preempted = false;
                const dueMs = (identity?.expiresAtMs ?? Date.now() + FALLBACK_WAIT_MS) + EXPIRY_GRACE_MS;
                await waitOrWake(dueMs - Date.now());
                if (shuttingDown) break;
                if (preempted) break;

                if (settled) {
                    const hasFollowUps =
                        typeof ctx.hasPendingMessages === "function" && ctx.hasPendingMessages();
                    if (queue.length === 0 && !hasFollowUps) {
                        // Finished early (or on time): hand the machine back now.
                        await finish(ctx, true);
                        return;
                    }
                    // More work queued while we ran; keep the slot and feed it.
                    await deliver(pi, ctx, queue.splice(0, queue.length));
                    continue;
                }

                // A failed delivery that started no run produces no settled event;
                // retry on the expiry wake-up so we never hold the slot idle while
                // prompts sit undelivered.
                if (queue.length > 0 && ctx.isIdle()) {
                    await deliver(pi, ctx, queue.splice(0, queue.length));
                    continue;
                }

                // Timer or message-triggered ownership re-check.
                const state = await fetchState();
                if (!state) {
                    await waitOrWake(FALLBACK_WAIT_MS);
                    continue;
                }
                if (isOurs(state.active)) {
                    adopt(state.active!);
                    status(ctx, `evo-x2: ours for ${formatRemaining(identity?.expiresAtMs)}`);
                    continue;
                }
                if (!state.active) {
                    // Our slot expired with nobody promoted ahead: retake it at the
                    // original allotment without interrupting a still-running agent.
                    const outcome = await reserve(originalMinutes);
                    if (outcome.kind === "held") continue;
                    status(ctx, `evo-x2: re-reserving — ${outcome.why}`);
                }
                // Occupied by something else: block execution and go back to waiting.
                preempted = true;
                try {
                    ctx.abort();
                } catch {
                    // The run may already be finishing on its own.
                }
                break;
            }
            if (shuttingDown) break;
            if (preempted) {
                identity = undefined;
                say(ctx, "lost the machine — requeueing; it will be retaken at the original allotment and the agent resumed", "warning");
            }
        }
    } finally {
        if (shuttingDown && identity) {
            identity = undefined;
            status(ctx, undefined);
            await releaseAndCancel();
        }
    }
    phase = "idle";
}

/** Leave the loop: go idle, cancel any queued row, release a held slot. */
async function finish(ctx: ExtensionCommandContext, releasedEarly: boolean): Promise<void> {
    const wasHeld = !!identity;
    phase = "idle";
    identity = undefined;
    status(ctx, undefined);
    await releaseAndCancel();
    if (wasHeld && releasedEarly) {
        say(ctx, "agent finished — released the machine early");
    }
}

// ------------------------------------------------------------------ extension

export default function (pi: ExtensionAPI): void {
    pi.on("session_start", () => {
        // Reload/new session: the previous supervisor is gone; the server-side
        // slot (if any) expires on its own.
        shuttingDown = false;
        phase = "idle";
        queue = [];
        identity = undefined;
        settled = false;
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
        queue.push({ text: event.text, minutes: originalMinutes });
        say(ctx, `queued behind the machine wait (${queue.length} pending)`);
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

    // Settled is the final idle signal and fires for aborted runs too (an Escape
    // cancel goes agent_end -> agent_settled, skipping agent_before_settle), so a
    // user cancelling the LLM early takes the same release path as a natural
    // finish: finish() frees the slot unless pi's own queue still holds pending
    // follow-ups or our preempt flag says the abort was ours (requeue, not release).
    pi.on("agent_settled", async () => {
        if (phase !== "running") return;
        settled = true;
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
        description: "Queue a prompt until the EVO-X2 machine is reserved (usage: /enqueue 45m <message>)",
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
                say(ctx, "usage: /enqueue <allotment> <message> — e.g. /enqueue 45m rebase the flake");
                return;
            }
            if (text === "status") {
                const lines = [`phase: ${phase}`, `pending messages: ${queue.length}`];
                if (identity) lines.push(`slot: ours, expires in ${formatRemaining(identity.expiresAtMs)}`);
                const state = await fetchState();
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
            const rest = text.slice(first.length).trim();
            if (minutes === undefined || !rest) {
                say(ctx, "usage: /enqueue <allotment> <message> — allotment is 90, 45m, 1h or 1h30", "warning");
                return;
            }

            // Off-gateway models need no reservation: deliver immediately.
            if (!onGateway(ctx)) {
                say(ctx, `current model is not served from "${GATEWAY_DOMAIN}" — sending without a reservation`);
                try {
                    await pi.sendUserMessage(rest);
                } catch {
                    queue.push({ text: rest, minutes: clampMinutes(minutes) });
                }
                return;
            }

            // Already holding the machine: this is just another follow-up.
            if (phase === "running" && identity) {
                try {
                    if (ctx.isIdle()) await pi.sendUserMessage(rest);
                    else await pi.sendUserMessage(rest, { deliverAs: "followUp" });
                    say(ctx, "machine is held — delivered as a follow-up");
                } catch {
                    queue.push({ text: rest, minutes: clampMinutes(minutes) });
                    wake();
                }
                return;
            }

            queue.push({ text: rest, minutes: clampMinutes(minutes) });
            if (phase === "waiting") {
                say(ctx, `added to the pending machine wait (${queue.length} queued)`);
                return;
            }

            // Idle: this handler hosts the supervisor until the work is done.
            await supervisor(pi, ctx);
        },
    });

    pi.registerCommand("dequeue", {
        description: "Drop queued EVO-X2 prompts; also cancels a pending wait or releases a held slot",
        handler: async (_args: string, ctx: ExtensionCommandContext) => {
            const dropped = queue.length;
            queue.length = 0;
            if (phase === "waiting") {
                // The supervisor sees the empty queue and cleans up.
                wake();
            } else if (phase === "running") {
                say(ctx, `dropped ${dropped} pending message(s); the slot is released when the agent finishes`);
            } else {
                await releaseAndCancel();
                identity = undefined;
                status(ctx, undefined);
                say(ctx, `dropped ${dropped} pending message(s)`);
            }
        },
    });
}
