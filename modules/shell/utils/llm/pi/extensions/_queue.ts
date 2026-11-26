/**
 * evo-x2-queue — a per-conversation lease on the shared EVO-X2 machine.
 *
 *   /enqueue <allotment> [comment]  want a slot; the comment is both the
 *                                   dashboard note and this conversation's
 *                                   identity among the reservations
 *   /enqueue status                 lease and machine state
 *   /dequeue                        give the slot back / stop wanting one
 *
 * Gating blocks `before_provider_request` until a lease is held, so a run pauses with
 * no first token while pi's own steering and follow-up queues keep collecting input.
 *
 * Two locks guard the machine, taken in this order and never held together longer
 * than necessary:
 *   - the reservation, server-side and one per comment, owned by whoever reserved it;
 *   - the wire, local and one conversation at a time, handed over when a run ends.
 *
 * Conversations that type the same comment deliberately share one reservation, and
 * take turns on the wire in arrival order. A sibling may borrow that reservation for
 * its turn but can never extend or release it. Waiting for a slot never holds the
 * wire, so a parked conversation cannot stall another that already has one.
 *
 * Per-conversation state is keyed by session id; cross-conversation state lives on
 * globalThis, because pi re-evaluates this module for every conversation.
 *
 * Env: EVO_X2_RESERVATIONS_URL (host serving /api/reservations),
 * EVO_X2_QUEUE_DOMAIN (substring matching a gated model, default "evo-x2").
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

/**
 * Timing knobs. Defaults are the polite production values; `EVO_X2_FAST=1`
 * shrinks every wait so tests exercise the same state machine in milliseconds
 * instead of minutes.
 */
const FAST = process.env.EVO_X2_FAST === "1";
const SCALE = FAST ? 1 / 150 : 1;
/** Bounds for "sleep min(5m, 2/3 of what is left), then poll again". */
const MIN_WAIT_MS = Math.max(120, 30_000 * SCALE);
const MAX_WAIT_MS = Math.max(400, 5 * 60_000 * SCALE);
/** A request reaching the gate with less than this left on the lease extends it. */
const EXTEND_HORIZON_MS = FAST ? 4_000 : 10 * 60_000;
/** Debounce for extension attempts; the ladder of shrink-on-409 stops at 5m. */
const EXTEND_DEBOUNCE_MS = Math.max(200, 30_000 * SCALE);
const EXTEND_MIN_MINUTES = 5;
/** Anything unreachable/unscheduled falls back to this pause. */
const FALLBACK_WAIT_MS = Math.max(300, 60_000 * SCALE);
const API_TIMEOUT_MS = 15_000;

/** Fallback key for contexts without a session manager (defensive only). */
const ANON_SCOPE = "__anon__";

/**
 * Shared process state.
 *
 * pi re-evaluates an extension module once per conversation: `loadExtensionsCached`
 * caches nothing useful here, so a module-level `const map = new Map()` gives every
 * conversation its own private copy. Anything that has to be seen by all of them —
 * who owns a note, who holds the wire, which conversations exist — must therefore
 * live on globalThis, which really is shared by the whole pi-web process.
 */
interface SharedState {
    /** Every conversation in this process, keyed by session id. */
    leases: Map<string, Lease>;
    /** Per-note ownership, wire holder and turn order. */
    noteGroups: Map<string, NoteGroup>;
    /** Counts auto-generated notes, so unlabelled conversations never collide. */
    serial: number;
}

const SHARED: SharedState = ((globalThis as any).__EVO_X2_QUEUE_STATE ??= {
    leases: new Map<string, Lease>(),
    noteGroups: new Map<string, NoteGroup>(),
    serial: 0,
});

/**
 * The one conversation entitled to act on the reservation each note names, plus the
 * one allowed to stream under it. Both are process-wide: pi-web runs several
 * conversations in a single process, and a per-conversation copy of either would let
 * every conversation with the same comment believe it owned the machine.
 */
interface NoteGroup {
    /** First to reserve; releases the row and hands the wire onward. */
    owner?: Lease;
    /** Whose request may be on the wire right now. */
    streaming?: Lease;
    /** Rows this note has already inserted, so no sibling queues a second time. */
    queued: Set<number | string>;
    /** Arrival order, so turns are first-come-first-served. */
    seats: Map<Lease, number>;
    seq: number;
}

const noteGroups = SHARED.noteGroups;

function noteGroup(note: string): NoteGroup {
    let group = noteGroups.get(note);
    if (!group) {
        group = { queued: new Set(), seats: new Map(), seq: 0 };
        noteGroups.set(note, group);
    }
    return group;
}

function usable(lease: Lease | undefined): boolean {
    return !!lease && !lease.dead && !lease.giveUp && lease.wantLease;
}

/** Who owns the reservation this note names? First claimer, until they let go. */
function noteHolder(note: string, claimer?: Lease): Lease | undefined {
    if (!note) return undefined;
    const group = noteGroup(note);
    if (!usable(group.owner)) {
        if (claimer) group.owner = claimer;
    }
    return group.owner;
}

/**
 * At least one OTHER live conversation is armed under this note? Tells a shared lease
 * apart from a private one, so bookkeeping can be skipped when nobody else is involved.
 */
function sharedGroup(note: string, self?: Lease): boolean {
    if (!note) return false;
    for (const lease of leases.values()) {
        if (lease === self || lease.dead || lease.giveUp || !lease.wantLease) continue;
        if (lease.note === note) return true;
    }
    return false;
}

/** Watching a sibling release a shared lease is cheap and should feel instant. */
const SHARED_POLL_MS = FAST ? 60 : 2_000;
/** How long an unscoped lease may sit idle before being dropped. */
const STALE_ANON_MS = 30 * 60_000;

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
    /** True while streaming on another conversation's reservation. */
    borrowed?: boolean;
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

// ------------------------------------------------------------------ helpers

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

/**
 * Sleep that `wake` cuts short; an abort signal cancels it too. `wake` is
 * called with the cancel function so the owning Lease can store it.
 */
function nap(ms: number, signal: AbortSignal | undefined, wake: (fn: () => void) => void): Promise<void> {
    const clamped = Math.max(1_000, Math.floor(ms));
    return new Promise((resolve) => {
        const finish = () => {
            clearTimeout(timer);
            wake(() => undefined);
            signal?.removeEventListener("abort", finish);
            resolve();
        };
        const timer = setTimeout(finish, clamped);
        if (typeof (timer as { unref?: () => void }).unref === "function") {
            (timer as { unref: () => void }).unref();
        }
        wake(finish);
        signal?.addEventListener("abort", finish, { once: true });
    });
}

function onGateway(model: { baseUrl?: string; provider?: string; id?: string } | undefined): boolean {
    if (!model) return false;
    const haystack =
        `${model.baseUrl ?? ""} ${model.provider ?? ""} ${model.id ?? ""}`.toLowerCase();
    return haystack.includes(GATEWAY_DOMAIN);
}

// ------------------------------------------------------------------ lease

/**
 * Everything mutable this extension owns, for exactly one conversation.
 * Instances live in `leases` below, keyed by session id; nothing here is ever
 * reached through a global "current" pointer, because several conversations
 * drive one pi-web process.
 */
class Lease {
    wantLease = false;
    note = "";
    wantedMinutes = DEFAULT_MINUTES;
    /** Rows we inserted, queued or active; part of the ownership anchor. */
    ourRows = new Set<number | string>();
    identity: Identity | undefined;
    giveUp = false;
    shuttingDown = false;
    /** When this conversation first armed; gates which rows it may adopt by note. */
    joinedAtMs = 0;
    /** Single-flight: every gate caller in this conversation awaits one pass. */
    flight: Promise<void> | undefined;
    private wakeFn: (() => void) | undefined;
    private lastExtendAttemptMs = 0;
    private lastSeenMs = Date.now();
    /** Last context carrying UI, so detached waits can still report status. */
    lastCtx: ExtensionContext | undefined;
    /** Set once the conversation is gone, so its claim cannot block anyone. */
    dead = false;
    /** True while this conversation has a request in flight or is mid-run. */
    running = false;
    /** True while an agent run is in progress for this conversation. */
    runningRun = false;

    touch(ctx?: ExtensionContext): void {
        this.lastSeenMs = Date.now();
        if (ctx) this.lastCtx = ctx;
    }

    stale(): boolean {
        return Date.now() - this.lastSeenMs > STALE_ANON_MS;
    }

    wake(): void {
        const fn = this.wakeFn;
        this.wakeFn = undefined;
        if (fn) fn();
    }

    // ---------------------------------------------------------- UI

    status(text: string | undefined): void {
        try {
            this.lastCtx?.ui.setStatus?.(STATUS_KEY, text);
        } catch {
            // UI may be gone during shutdown.
        }
    }

    say(text: string, level: "info" | "warning" | "error" = "info"): void {
        try {
            this.lastCtx?.ui.notify?.(`evo-x2: ${text}`, level);
        } catch {
            // UI may be gone during shutdown.
        }
    }

    heldStatus(): string {
        return `evo-x2: lease ours for ${formatRemaining(this.identity?.expiresAtMs)} — /dequeue to release`;
    }

    // ---------------------------------------------------------- identity

    /**
     * An active row that merely shares our IP is not enough: pi-web hands every
     * conversation the same address. Either we inserted it (id, which survives
     * waitlist promotion) or it carries exactly our comment.
     */
    ownsNote(row: { note?: string } | null | undefined): boolean {
        return !!this.note && !!row && oneLine(row.note ?? "") === this.note;
    }

    /**
     * Our group owns the slot: we inserted the row (ids survive waitlist
     * promotion), or it carries our note and we joined while it was being taken.
     *
     * Matching a note makes a row ours to act on; the right to put a request on the
     * wire is decided separately, by the note's turn token.
     */
    isOurs(active: ActiveReservation | null | undefined): boolean {
        if (!active) return false;
        if (this.identity && active.id === this.identity.id) return true;
        if (this.ourRows.has(active.id)) return true;
        // A row carrying our comment belongs to whoever in this process reserved it
        // first. Siblings that typed the same note must not each act as its owner:
        // they share one machine, and only one of them can hold it at a time.
        if (this.ownsNote(active)) return noteHolder(this.note) === this;
        return false;
    }

    // ------------------------------------------------- exclusive streaming right

    /** Any other live conversation still standing in this note's line? */
    othersWaiting(): boolean {
        if (!this.note) return false;
        const group = noteGroups.get(this.note);
        if (!group) return false;
        for (const [lease] of group.seats) {
            if (lease !== this && usable(lease)) return true;
        }
        return false;
    }

    /** Whether this conversation may put a request on the wire. */
    holdsTurn(): boolean {
        if (!this.note) return true;
        return noteGroups.get(this.note)?.streaming === this;
    }

    /** Note that a run started; only meaningful while we hold the wire. */
    markRunning(): void {
        if (this.holdsTurn()) this.running = true;
    }

    /**
     * Hand the wire to whoever is next in line. The group is shared by every
     * conversation using this note, so a conversation may only give up a wire it
     * actually holds; clearing it any other way lets two of them stream together.
     */
    releaseTurn(): void {
        this.running = false;
        if (!this.note) return;
        const group = noteGroups.get(this.note);
        if (!group || group.streaming !== this) return;
        group.streaming = undefined;
        group.seats.delete(this);
    }

    /** Drop every trace of this conversation from its note (session gone). */
    forgetTurn(): void {
        this.running = false;
        if (!this.note) return;
        const group = noteGroups.get(this.note);
        if (!group) return;
        if (group.streaming === this) group.streaming = undefined;
        if (group.owner === this) group.owner = undefined;
        group.seats.delete(this);
    }

    /** True once any of our rows sits in the waitlist, so we never queue twice. */
    inLine(): boolean {
        return this.ourRows.size > 0;
    }

    /**
     * Whether this note already has a place in the server's waitlist — ours or a
     * sibling's. Conversations sharing a comment share one queue entry too: the
     * first to arrive inserts it, and the rest wait on that same promotion rather
     * than each inserting their own and multiplying reservations.
     */
    noteQueued(state?: ReservationState): boolean {
        if (!this.note) return false;
        const group = noteGroups.get(this.note);
        if (group?.queued.size) return true;
        if (!state?.queue) return false;
        return state.queue.some((entry) => this.ownsNote(entry));
    }

    /**
     * Use another conversation's reservation for one turn. The row stays theirs:
     * we never release or extend what we did not reserve, and give the wire back
     * as soon as our run ends.
     */
    borrow(active: ActiveReservation): void {
        this.identity = {
            id: active.id,
            borrowed: true,
            expiresAtMs:
                typeof active.expires_at === "number"
                    ? active.expires_at * 1000
                    : Date.now() + this.wantedMinutes * 60_000,
        };
    }

    adopt(active: ActiveReservation): void {
        const expiresAtMs =
            typeof active.expires_at === "number"
                ? active.expires_at * 1000
                : Date.now() + this.wantedMinutes * 60_000;
        this.identity = { id: active.id, expiresAtMs };
        this.ourRows.add(active.id);
    }


    // ---------------------------------------------------------- API calls

    async api<T = Record<string, unknown>>(
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

    async fetchState(): Promise<ReservationState | undefined> {
        try {
            return await this.api<ReservationState>("");
        } catch {
            return undefined;
        }
    }

    /**
     * POST /acquire with a time-boxed request carrying our comment as its note.
     *
     * - 200 acquired                   -> the slot is ours.
     * - 200 already_active             -> whatever this IP holds; only ours when
     *                                    its note is our comment.
     * - 200 queued                     -> someone holds it; wait out their remainder.
     * - 409 "Maximum available time is Xm" -> the box is free but a scheduled slot
     *   cuts the allotment short; retry once with X - 5 minutes (bounded recursion).
     */
    async reserve(minutes: number, depth = 0): Promise<ReserveOutcome> {
        try {
            const res = await this.api<{ status?: string; state?: ReservationState }>("/acquire", {
                mode: "timeboxed",
                duration: Math.round(minutes),
                note: this.note,
            });
            const act = res.state?.active;
            if (res.status === "acquired" && act) {
                this.adopt(act);
                return { kind: "held" };
            }
            // An active row that merely carries our comment is NOT ours. Two people
            // typing the same note share one reservation on the server; adopting it
            // would make each of them an owner who streams immediately — and who can
            // release the machine while the other is still working.
            if (res.status === "already_active" && act && this.ourRows.has(act.id)) {
                this.adopt(act);
                return { kind: "held" };
            }
            // Remember the row this note just inserted — for us and for every
            // sibling sharing the comment — so none of them queues a second one.
            this.harvestRow(res.state);
            if (this.note) {
                const group = noteGroup(this.note);
                for (const id of this.ourRows) group.queued.add(id);
            }
            return { kind: "retry", retryMs: holderWaitMs(act), why: "queued behind the current holder" };
        } catch (err) {
            if (err instanceof ApiError && err.status === 409) {
                const match = /Maximum available time is (\d+)m/i.exec(err.message);
                if (match) {
                    const available = Number(match[1]);
                    const viable = available - COLLISION_SLACK_MINUTES;
                    if (viable >= MIN_VIABLE_MINUTES && depth < 4) return this.reserve(viable, depth + 1);
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

    /**
     * Remember the waitlist row our own acquire inserted. Rows other conversations
     * queued under their own comments are left to them, which is what keeps one
     * /dequeue from wiping a sibling's place in line.
     */
    harvestRow(state?: ReservationState): void {
        const ip = state?.client?.ip;
        if (!ip || !state?.queue) return;
        let newest: QueueEntry | undefined;
        for (const entry of state.queue) {
            if (entry.client_ip !== ip || this.ourRows.has(entry.id)) continue;
            if (!newest || (entry.created_at ?? 0) > (newest.created_at ?? 0)) newest = entry;
        }
        if (newest) this.ourRows.add(newest.id);
    }

    /**
     * POST /extend — roll the lease forward by the original allotment. The API
     * adds minutes to `max(now, expires_at)` of our own active timeboxed row and
     * answers 409 when the new horizon overlaps a scheduled slot; the step is
     * then halved down to a 5m floor. Any other failure leaves the current
     * expiry standing for the next gate.
     */
    async tryExtend(): Promise<void> {
        if (Date.now() - this.lastExtendAttemptMs < EXTEND_DEBOUNCE_MS) return;
        this.lastExtendAttemptMs = Date.now();
        const base = Math.min(240, Math.max(EXTEND_MIN_MINUTES, this.wantedMinutes));
        for (let attempt = 0; attempt < 4; attempt++) {
            const minutes = Math.max(EXTEND_MIN_MINUTES, Math.floor(base / 2 ** attempt));
            try {
                const res = await this.api<{ status?: string; state?: ReservationState }>("/extend", { minutes });
                const act = res.state?.active;
                if (act && this.isOurs(act)) this.adopt(act);
                return;
            } catch (err) {
                if (err instanceof ApiError && err.status === 409 && minutes > EXTEND_MIN_MINUTES) continue;
                return;
            }
        }
    }

    /**
     * Give back only what is ours. The server keys release/cancel by client IP,
     * so blanket calls would free a sibling conversation's active lease or wipe
     * its waitlist rows: release fires solely while the live active row passes
     * the ownership test, and waitlist rows are cancelled one by one by id.
     */
    async releaseAndCancel(): Promise<void> {
        const state = await this.fetchState();
        if (!state) return; // unreachable: let rows expire rather than guess blindly
        // Renting a sibling's slot says nothing about owning it: they decide when it
        // ends. We simply stop using it.
        if (this.identity?.borrowed) return;
        if (state.active && this.isOurs(state.active)) {
            try {
                await this.api("/release", {});
            } catch {
                // The server expires the slot on its own.
            }
        }
        for (const row of state.queue) {
            if (!this.ourRows.has(row.id) && !this.ownsNote(row)) continue;
            try {
                await this.api("/cancel", { id: row.id });
                this.ourRows.delete(row.id);
            } catch {
                // Gone already.
            }
        }
    }

    // ---------------------------------------------------------- the gate

    async ensureLease(signal?: AbortSignal): Promise<void> {
        while (this.wantLease && !this.giveUp && !this.shuttingDown && !signal?.aborted) {
            const state = await this.fetchState();
            if (!state) {
                this.status("evo-x2: reservations API unreachable — retrying");
                await this.nap(FALLBACK_WAIT_MS, signal);
                continue;
            }
            // An identity only lives while its row is the active one.
            if (this.identity && state.active?.id !== this.identity.id) this.identity = undefined;
            // Waitlist rows the server no longer lists were dropped (cancelled or
            // retained away): forget them so the join-the-FIFO check stays honest.
            if (state.active && !this.isOurs(state.active)) {
                for (const id of this.ourRows) {
                    if (!state.queue?.some((e) => e.id === id)) this.ourRows.delete(id);
                }
            }
            // Someone else holds the box: join the FIFO once with our own comment
            // (or a sibling's identical one), then watch for promotion.
            if (
                state.active &&
                !this.isOurs(state.active) &&
                !this.inLine() &&
                !this.noteQueued(state)
            ) {
                const outcome = await this.reserve(this.wantedMinutes);
                if (outcome.kind === "held") {
                    this.status(this.heldStatus());
                    return;
                }
                this.status(`evo-x2: waiting — ${outcome.why}`);
            }
            if (this.isOurs(state.active)) {
                // Our own reservation: take the wire, then hold or extend it.
                if (!(await this.waitForTurn(signal))) return;
                this.adopt(state.active!);
                if (this.identity && this.identity.expiresAtMs - Date.now() < EXTEND_HORIZON_MS) {
                    await this.tryExtend();
                    if (!this.identity || this.identity.expiresAtMs <= Date.now()) continue;
                }
                this.status(this.heldStatus());
                return;
            }
            // A sibling in this process holds the machine under the same comment.
            // Waiting for our own row would hang forever — the group shares one
            // reservation by design — so we borrow it for our turn instead.
            if (state.active && this.ownsNote(state.active)) {
                if (!(await this.waitForTurn(signal))) return;
                this.borrow(state.active);
                this.status(`evo-x2: your turn on "${this.note}"`);
                return;
            }
            if (!state.active && !this.inLine() && !this.noteQueued(state)) {
                const outcome = await this.reserve(this.wantedMinutes);
                if (outcome.kind === "held") {
                    this.status(this.heldStatus());
                    return;
                }
                this.status(`evo-x2: waiting — ${outcome.why}`);
                await this.nap(outcome.retryMs, signal);
                continue;
            }
            if (!state.active) {
                // Our row is the only thing standing between us and the machine;
                // the server promotes it on its next read.
                this.status("evo-x2: next in line");
                await this.nap(MIN_WAIT_MS, signal);
                continue;
            }
            // Somebody else's machine, and we are in line for it. Give the wire back
            // and come away empty-handed: sitting on it while parked would stall every
            // other conversation, and sleeping here would keep this caller out of the
            // gate. The gate re-checks on its own clock until the FIFO promotes us.
            this.releaseTurn();
            this.status(
                `evo-x2: held by ${state.active.client_name ?? "another client"} (${formatDuration(state.active.remaining_seconds)} left)`,
            );
            return;
        }
    }

    /**
     * The gate for every provider request. Returns only once this conversation both
     * holds a reservation (its own, or a borrowed turn on a sibling's) and owns the
     * wire; until then the request simply waits, with no first token.
     */
    async gate(signal?: AbortSignal): Promise<void> {
        if (!this.wantLease || this.giveUp) return;
        // Two locks, taken in this order and never held together longer than needed:
        // the reservation (server-side, one per note) and the wire (local, one
        // conversation at a time). Waiting for the machine must not sit on the wire,
        // or a parked conversation stalls everyone else's already-held lease.
        while (!signal?.aborted && !this.giveUp && !this.shuttingDown) {
            // Join the reservation pass already running for this conversation, or
            // start one. Only the starter clears it, so a second caller never waits
            // on a pass it cannot influence.
            const mine = !this.flight;
            if (mine) {
                this.flight = this.ensureLease(signal).finally(() => {
                    this.flight = undefined;
                });
            }
            await this.flight;
            if (this.identity) {
                if (await this.waitForTurn(signal)) return;
                continue;
            }
            // No slot yet, so nothing may go out on the wire. Someone else is driving
            // the pass: wake as soon as it lands and look again, rather than parking a
            // request that would either stream unreserved or spin beside the driver.
            if (!mine) {
                await this.nap(MIN_WAIT_MS, signal);
                continue;
            }
        }
    }

    /**
     * Block until this conversation may put a request on the wire. Conversations
     * sharing a note share one line: a numbered seat each, and a single holder of
     * the wire. It moves when the holder's run ends, or at once if it dies or
     * disarms. False means the wait was cancelled.
     */
    async waitForTurn(signal?: AbortSignal): Promise<boolean> {
        if (!this.note) {
            this.running = true;
            return true;
        }
        const group = noteGroup(this.note);
        // Mid-run turns re-enter the gate: whoever holds the wire keeps streaming.
        if (group.streaming === this) {
            this.running = true;
            return true;
        }
        // A numbered place in line, taken once, so repeat prompts keep their spot.
        let seat = group.seats.get(this);
        if (seat === undefined) {
            seat = ++group.seq;
            group.seats.set(this, seat);
        }
        for (;;) {
            if (signal?.aborted || this.giveUp || this.shuttingDown) {
                group.seats.delete(this);
                return false;
            }
            // Somebody else holds the wire: never cut in front of them. Their
            // agent_end is what hands it over.
            if (usable(group.streaming)) {
                this.status(`evo-x2: waiting — another session is using "${this.note}"`);
                await this.nap(SHARED_POLL_MS, signal);
                continue;
            }
            // Free wire: take the place in line that comes first.
            const ahead = [...group.seats.entries()].filter(
                ([l, n]) => l !== this && n < seat && usable(l),
            ).length;
            if (ahead > 0) {
                this.status(`evo-x2: waiting — ${ahead} session(s) ahead on "${this.note}"`);
                await this.nap(SHARED_POLL_MS, signal);
                continue;
            }
            group.streaming = this;
            this.running = true;
            return true;
        }
    }

    private nap(ms: number, signal?: AbortSignal): Promise<void> {
        return nap(ms, signal, (fn) => {
            this.wakeFn = fn;
        });
    }

    // ---------------------------------------------------------- lifecycle

    reset(ctx?: ExtensionContext): void {
        this.forgetTurn();
        this.wantLease = false;
        this.giveUp = false;
        this.shuttingDown = false;
        this.joinedAtMs = 0;
        this.note = "";
        this.wantedMinutes = DEFAULT_MINUTES;
        this.ourRows = new Set();
        this.identity = undefined;
        this.flight = undefined;
        this.touch(ctx);
        this.status(undefined);
    }

    async disarm(): Promise<void> {
        const wasHeld = !!this.identity;
        this.wantLease = false;
        this.giveUp = true;
        this.wake(); // unblock any in-flight gate: it lets requests through
        this.status(undefined);
        // Requests in flight are let through unreserved (pi's run continues).
        // Only our own rows are given back; siblings on this IP keep theirs.
        await this.releaseAndCancel();
        this.identity = undefined;
        this.ourRows.clear();
        this.releaseTurn();
        // Wipe the note's bookkeeping so a later /enqueue queues from scratch — but
        // only when we owned it and nobody else is still standing behind the comment.
        const group = this.note ? noteGroups.get(this.note) : undefined;
        if (group && group.owner === this && !sharedGroup(this.note, this)) {
            group.queued.clear();
            group.owner = undefined;
        }
        this.say(wasHeld ? "released the machine" : "lease disarmed");
    }

    async settleRelease(ctx: ExtensionContext): Promise<void> {
        this.touch(ctx);
        if (!this.wantLease || this.giveUp || !this.identity) return;
        if (ctx.hasPendingMessages?.()) return; // queued steer/follow-ups mean work remains
        // Work is done: hand the wire to the next conversation in line.
        this.releaseTurn();
        // Renting a sibling's reservation says nothing about owning it — they decide
        // when it ends, and releasing here would cut them off mid-run.
        if (this.identity.borrowed) {
            this.identity = undefined;
            this.status("evo-x2: turn over — the machine stays with its owner");
            return;
        }
        // Siblings waiting under the same comment keep the shared reservation alive;
        // giving it up now would strand their next request.
        if (this.othersWaiting()) {
            this.status(`evo-x2: "${this.note}" held for follow-ups — /dequeue to release`);
            return;
        }
        const left = formatRemaining(this.identity.expiresAtMs);
        await this.releaseAndCancel(); // ownership-checked against the live server state
        this.identity = undefined;
        this.ourRows.clear();
        this.status("evo-x2: idle — released; the next request will re-queue");
        this.say(`work settled with ${left} left — released the machine; next request re-queues`);
    }

    async shutdownRelease(): Promise<void> {
        this.shuttingDown = true;
        this.dead = true;
        this.wake();
        this.forgetTurn();
        if (this.identity || this.ourRows.size) await this.releaseAndCancel();
    }
}

// ---------------------------------------------------- leases per conversation

/**
 * Keyed by session id, so pi-web's conversations never share a lease. Entries
 * are created lazily: a conversation that never runs /enqueue costs nothing.
 */
const leases = SHARED.leases;

function scopeOf(ctx: Pick<ExtensionContext, "sessionManager"> | undefined): string {
    const id = ctx?.sessionManager?.getSessionId?.();
    return typeof id === "string" && id ? id : ANON_SCOPE;
}

/**
 * Default dashboard note. It doubles as the ownership anchor, so it must be
 * unique per conversation: derive it from the session id rather than using a
 * constant that every conversation would collide on.
 */
function defaultNote(ctx: ExtensionContext): string {
    const id = ctx.sessionManager?.getSessionId?.();
    const label = typeof id === "string" && id ? id.slice(0, 8) : `pid${process.pid}-${++SHARED.serial}`;
    return `pi ${label}`;
}

function leaseFor(ctx: Pick<ExtensionContext, "sessionManager"> | undefined): Lease {
    const key = scopeOf(ctx);
    let lease = leases.get(key);
    if (!lease) {
        // Unscoped contexts cannot be told apart, so drop stale ones rather
        // than hand a fresh conversation somebody else's lease.
        if (key === ANON_SCOPE) {
            for (const [k, stale] of leases) {
                if (k === ANON_SCOPE && stale.stale()) leases.delete(k);
            }
        }
        lease = new Lease();
        leases.set(key, lease);
    }
    return lease;
}

// ------------------------------------------------------------------ extension

export default function (pi: ExtensionAPI): void {

    pi.on("session_start", async (event, ctx) => {
        const lease = leaseFor(ctx);
        // Reload/new session: no lease wanted, and any previous wait is gone; a
        // server-side slot (if one was still held) expires on its own.
        if (event.reason === "reload" || event.reason === "new" || event.reason === "fork") {
            lease.reset(ctx);
        } else {
            lease.touch(ctx);
        }
    });

    // Awaited so the release lands before the process goes away.
    pi.on("session_shutdown", async (_event, ctx) => {
        await leaseFor(ctx).shutdownRelease();
    });

    // The gate. Awaits before the /v1/chat/completions (or other provider)
    // request goes out: while the lease is not ours, the run simply waits with
    // no first token, and pi's own queueing keeps collecting everything typed.
    pi.on("agent_start", async (_event, ctx) => {
        // Marks a run in progress. It fires before `before_provider_request`, so it
        // must not claim the wire — a conversation still queued behind a sibling
        // would otherwise end up waiting on its own flag forever.
        const lease = leaseFor(ctx);
        lease.touch(ctx);
        lease.runningRun = true;
        lease.markRunning();
    });

    pi.on("before_provider_request", async (_event, ctx) => {
        const lease = leaseFor(ctx);
        lease.touch(ctx);
        if (!lease.wantLease || lease.giveUp || !onGateway(ctx.model)) return undefined;
        await lease.gate(ctx.signal);
        return undefined;
    });

    // The machine is shared hardware: hand the slot back as soon as the agent
    // is done with it. The gate stays armed, so a follow-up prompt simply
    // re-queues and — the box usually still free — re-acquires it.
    pi.on("agent_end", async (_event, ctx) => {
        const lease = leaseFor(ctx);
        lease.touch(ctx);
        lease.runningRun = false;
        // Handover point: this conversation is done streaming, so the next one in
        // line for the same note may go.
        lease.releaseTurn();
    });

    pi.on("agent_settled", async (_event, ctx) => {
        const lease = leaseFor(ctx);
        lease.touch(ctx);
        // Nothing more is coming for this conversation: make sure it is not still
        // standing on the wire, whatever happened to its agent_end.
        lease.runningRun = false;
        lease.releaseTurn();
        await lease.settleRelease(ctx);
    });

    pi.on("model_select", async (event, ctx) => {
        const lease = leaseFor(ctx);
        lease.touch(ctx);
        if (!lease.wantLease) return;
        if (!onGateway(event.model)) {
            lease.say(
                `model left the "${GATEWAY_DOMAIN}" gateway; the lease gate stays closed for it until you /dequeue and re-arm`,
                "warning",
            );
        }
    });

    pi.registerCommand("enqueue", {
        description: "Request an EVO-X2 lease for this conversation; provider requests pause until it is held (usage: /enqueue 45m rebasing the flake)",
        getArgumentCompletions: (prefix: string) => {
            const needle = (prefix ?? "").trimStart().split(/\s+/)[0] ?? "";
            if (!needle && !prefix) return null;
            const options = ["15m", "30m", "1h", "2h", "4h", "status"]
                .filter((value) => value.startsWith(needle))
                .map((value) => ({ value, label: value }));
            return options.length > 0 ? options : null;
        },
        handler: async (args: string, ctx: ExtensionCommandContext) => {
            const lease = leaseFor(ctx);
            lease.touch(ctx);
            const text = (args ?? "").trim();
            if (!text) {
                lease.say("usage: /enqueue <allotment> [comment] — e.g. /enqueue 45m rebasing the flake");
                return;
            }
            if (text === "status") {
                const lines: string[] = [];
                lines.push(`gate: ${lease.wantLease ? (lease.giveUp ? "given up" : "armed") : "disarmed (no /enqueue this conversation)"}`);
                if (lease.note) lines.push(`comment: ${lease.note}`);
                if (lease.identity) lines.push(`lease: ours, expires in ${formatRemaining(lease.identity.expiresAtMs)}`);
                const state = await lease.fetchState();
                const position = state?.client?.queue_position;
                if (position) lines.push(`queue position: ${position}`);
                if (state?.active && !lease.isOurs(state.active)) {
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
                lease.say("usage: /enqueue <allotment> [comment] — allotment is 90, 45m, 1h or 1h30", "warning");
                return;
            }
            const comment = oneLine(text.slice(first.length));

            if (!onGateway(ctx.model)) {
                lease.say(`current model is not served from "${GATEWAY_DOMAIN}" — no reservation needed`, "warning");
                return;
            }

            if (!lease.wantLease) lease.joinedAtMs = Date.now();
            lease.wantedMinutes = clampMinutes(minutes);
            if (comment) lease.note = comment;
            if (!lease.wantLease) lease.note ||= defaultNote(ctx);
            const wasArmed = lease.wantLease && !lease.giveUp;
            lease.wantLease = true;
            lease.giveUp = false;
            // Claim the comment before any round trip. Conversations can arm within
            // the same tick, and if each only staked its claim once the acquire came
            // back, all of them would insert a row and collect one reservation each
            // instead of sharing the single one this comment stands for.
            noteHolder(lease.note, lease);
            lease.say(`lease armed for ${formatDuration(lease.wantedMinutes * 60)} — requests pause until the machine is ours`);
            // Chase the slot in the background so the first prompt is not stuck on a
            // round trip — but only while no request is gated, and only for the note's
            // owner. A sibling acquiring behind someone else's back would put a second
            // reservation on the machine and stream beside them.
            const group = noteGroups.get(lease.note);
            const idle = !lease.flight && !group?.streaming;
            if ((!wasArmed || idle) && noteHolder(lease.note) === lease) {
                lease.flight ??= lease.ensureLease().finally(() => {
                    lease.flight = undefined;
                });
            }
        },
    });

    pi.registerCommand("dequeue", {
        description: "Release this conversation's EVO-X2 lease and stop gating requests on it",
        handler: async (_args: string, ctx: ExtensionCommandContext) => {
            const lease = leaseFor(ctx);
            lease.touch(ctx);
            await lease.disarm();
        },
    });
}
