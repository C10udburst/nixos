'use strict';

/**
 * n8n node for Pi Web (https://github.com/agegr/pi-web).
 *
 * Pi Web drives one pi session per working directory it is told about, and its
 * HTTP surface is two POSTs: /api/agent/new spawns a session in a `cwd` and
 * answers with pi's real session id, /api/agent/:id forwards one command to
 * that session. Slash commands are sent as prompts, which is exactly what the
 * web composer does, so `/enqueue 45m rebasing the flake` reaches the queue
 * extension registered in the agent directory of that instance.
 *
 * The order matters: `/enqueue` arms the lease gate for the conversation and
 * returns while it chases the slot in the background, so the prompt that is
 * sent right after it queues behind the gate instead of burning provider
 * requests before the machine is ours.
 */

const DEFAULT_TIMEOUT_MS = 60000;
const MAX_ERROR_BODY = 400;

function text(value) {
	return typeof value === 'string' ? value.trim() : '';
}

function requiredText(value, label) {
	const trimmed = text(value);
	if (trimmed === '') {
		throw new Error(`The node needs a non-empty ${label}`);
	}
	return trimmed;
}

function normalizeBaseUrl(value) {
	const raw = text(value);
	if (raw === '') {
		throw new Error('The Pi Web API credential has no Base URL');
	}
	let url;
	try {
		url = new URL(raw);
	} catch (error) {
		throw new Error(`Pi Web Base URL is not a valid URL: ${raw}`);
	}
	if (url.protocol !== 'http:' && url.protocol !== 'https:') {
		throw new Error(`Pi Web Base URL must be http or https, got ${raw}`);
	}
	// The API paths are appended as-is, so a mounted instance keeps its prefix.
	return raw.replace(/\/+$/, '');
}

function basicAuth(password) {
	return 'Basic ' + Buffer.from(`pi-web:${password}`, 'utf8').toString('base64');
}

/**
 * One POST to Pi Web. No browser headers are sent on purpose: Pi Web rejects
 * API requests whose `Sec-Fetch-Site` is cross-site and compares `Origin`
 * against the Host header, so a plain server-to-server call without either is
 * the one shape that always passes its request-security check.
 */
async function postToPiWeb(baseUrl, authorization, apiPath, body, timeoutMs) {
	const url = `${baseUrl}${apiPath}`;
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), timeoutMs);

	let response;
	try {
		response = await fetch(url, {
			method: 'POST',
			headers: {
				'content-type': 'application/json',
				accept: 'application/json',
				...(authorization ? { authorization } : {}),
			},
			body: JSON.stringify(body),
			signal: controller.signal,
		});
	} catch (error) {
		const reason =
			error && error.name === 'AbortError'
				? `timed out after ${timeoutMs}ms`
				: (error && error.message) || String(error);
		throw new Error(`Could not reach Pi Web at ${url}: ${reason}`);
	} finally {
		clearTimeout(timer);
	}

	const raw = await response.text();
	let payload = null;
	if (raw !== '') {
		try {
			payload = JSON.parse(raw);
		} catch (error) {
			payload = { error: raw.slice(0, MAX_ERROR_BODY) };
		}
	}

	if (!response.ok) {
		const detail = (payload && payload.error) || raw.slice(0, MAX_ERROR_BODY) || response.statusText;
		const rejected = payload && payload.code === 'prompt_rejected' ? ' (the prompt was not accepted)' : '';
		throw new Error(`Pi Web answered ${response.status} for ${apiPath}${rejected}: ${detail}`);
	}

	return payload;
}

/** `/enqueue <allotment> <comment>`, the line the queue extension parses. */
function enqueueLine(allotment, comment) {
	const parts = ['/enqueue'];
	const duration = text(allotment);
	const note = text(comment).replace(/\s+/g, ' ');
	if (duration !== '') parts.push(duration);
	if (note !== '') parts.push(note);
	if (parts.length === 1) {
		throw new Error('An allotment or a comment is needed to build the /enqueue line');
	}
	return parts.join(' ');
}

/** `execute` is called with the context either as `this` or as the argument. */
function contextOf(context) {
	if (context && typeof context.getNodeParameter === 'function') return context;
	return this;
}

async function runItem(ctx, itemIndex) {
	const action = text(ctx.getNodeParameter('action', itemIndex)) || 'enqueuePrompt';
	const directory = requiredText(ctx.getNodeParameter('directory', itemIndex), 'working directory');
	const options = ctx.getNodeParameter('options', itemIndex, {}) || {};

	const timeoutRaw = Number(options.timeout);
	const timeoutMs = Number.isFinite(timeoutRaw) && timeoutRaw > 0 ? timeoutRaw : DEFAULT_TIMEOUT_MS;

	const credential = await ctx.getCredentials('piWebApi', itemIndex);
	const baseUrl = normalizeBaseUrl(credential.baseUrl);
	const authorization = text(credential.password) ? basicAuth(text(credential.password)) : null;

	const provider = text(options.provider);
	const modelId = text(options.modelId);
	if ((provider === '') !== (modelId === '')) {
		throw new Error('Provider and Model ID are only understood together');
	}

	// 1. A session of its own in the requested directory.
	const sessionBody = { cwd: directory, type: 'ensure_session' };
	if (provider !== '') {
		sessionBody.provider = provider;
		sessionBody.modelId = modelId;
	}
	const created = await postToPiWeb(baseUrl, authorization, '/api/agent/new', sessionBody, timeoutMs);
	const sessionId = created && created.sessionId;
	if (!sessionId) {
		throw new Error('Pi Web created no session: the reply carried no sessionId');
	}

	const send = (message) =>
		postToPiWeb(baseUrl, authorization, `/api/agent/${encodeURIComponent(sessionId)}`, { type: 'prompt', message }, timeoutMs);

	// 2. The lease, then 3. the prompt that has to wait for it.
	let command = null;
	let commandResult = null;
	if (action === 'enqueuePrompt' || action === 'command') {
		const override = text(ctx.getNodeParameter('commandOverride', itemIndex, ''));
		command =
			override !== ''
				? override
				: enqueueLine(
						ctx.getNodeParameter('allotment', itemIndex, ''),
						ctx.getNodeParameter('comment', itemIndex, ''),
					);
		commandResult = await send(command);
	}

	let prompt = null;
	let promptResult = null;
	if (action === 'enqueuePrompt' || action === 'prompt') {
		prompt = requiredText(ctx.getNodeParameter('prompt', itemIndex, ''), 'prompt');
		promptResult = await send(prompt);
	}

	return {
		json: {
			sessionId,
			sessionUrl: `${baseUrl}/?session=${encodeURIComponent(sessionId)}`,
			directory,
			action,
			command: commandResult === null ? null : command,
			prompt,
			// Pi Web answers `{ queued: true }` while an earlier run still holds
			// the conversation, which is the normal case straight after /enqueue.
			commandResponse: commandResult ? commandResult.data ?? null : null,
			promptResponse: promptResult ? promptResult.data ?? null : null,
			model: created.model ?? null,
			thinkingLevel: created.thinkingLevel ?? null,
		},
	};
}

class PiWeb {
	constructor() {
		this.description = {
			displayName: 'Pi Web',
			name: 'piWeb',
			group: ['transform'],
			version: 1,
			defaults: {
				name: 'Pi Web',
				icon: 'fa:robot',
			},
			description: 'Start a Pi Web session in a directory, arm /enqueue, then send the prompt',
			documentationUrl: 'https://github.com/agegr/pi-web',
			inputs: ['main'],
			outputs: ['main'],
			credentials: [
				{
					name: 'piWebApi',
					required: true,
				},
			],
			properties: [
				{
					displayName: 'Action',
					name: 'action',
					type: 'options',
					default: 'enqueuePrompt',
					description: 'What the new session gets',
					options: [
						{
							name: 'Enqueue and Prompt',
							value: 'enqueuePrompt',
							description: 'Send /enqueue for the lease, then the prompt behind that gate',
						},
						{
							name: 'Prompt Only',
							value: 'prompt',
							description: 'Send the prompt with no lease in front of it',
						},
						{
							name: 'Command Only',
							value: 'command',
							description: 'Send the command line and stop, for example to arm a lease by hand',
						},
						{
							name: 'Create Session Only',
							value: 'session',
							description: 'Only open the session in the directory and report its id',
						},
					],
				},
				{
					displayName: 'Working Directory',
					name: 'directory',
					type: 'string',
					default: '',
					required: true,
					placeholder: '/home/cloudburst/nixos',
					description: 'Directory on the Pi Web host the session starts in',
				},
				{
					displayName: 'Allotment',
					name: 'allotment',
					type: 'string',
					default: '45m',
					displayOptions: {
						show: {
							action: ['enqueuePrompt', 'command'],
						},
					},
					placeholder: '45m',
					description: 'Lease length for /enqueue: 90, 45m, 1h, 1h30 — or status to ask where the queue stands. A session on a model served from outside the EVO-X2 gateway just reports that no reservation is needed',
				},
				{
					displayName: 'Comment',
					name: 'comment',
					type: 'string',
					default: '',
					displayOptions: {
						show: {
							action: ['enqueuePrompt', 'command'],
						},
					},
					placeholder: 'rebasing the flake',
					description: 'What the lease is for, shown to everyone standing on the same machine',
				},
				{
					displayName: 'Command Override',
					name: 'commandOverride',
					type: 'string',
					default: '',
					displayOptions: {
						show: {
							action: ['enqueuePrompt', 'command'],
						},
					},
					placeholder: '/enqueue status',
					description: 'Sent instead of the assembled /enqueue line, for any other slash command',
				},
				{
					displayName: 'Prompt',
					name: 'prompt',
					type: 'string',
					default: '',
					required: true,
					typeOptions: {
						alwaysOpenEditWindow: true,
					},
					displayOptions: {
						show: {
							action: ['enqueuePrompt', 'prompt'],
						},
					},
					description: 'The instruction the session gets once the lease is ours',
				},
				{
					displayName: 'Options',
					name: 'options',
					type: 'collection',
					placeholder: 'Add Option',
					default: {},
					options: [
						{
							displayName: 'Model ID',
							name: 'modelId',
							type: 'string',
							default: '',
							description: 'Model the session starts on; needs Provider as well',
						},
						{
							displayName: 'Provider',
							name: 'provider',
							type: 'string',
							default: '',
							description: 'Provider of Model ID, as the instance lists it',
						},
						{
							displayName: 'Timeout (ms)',
							name: 'timeout',
							type: 'number',
							default: DEFAULT_TIMEOUT_MS,
							description: 'How long each request waits for Pi Web',
						},
					],
				},
			],
		};
	}

	async execute(context) {
		const ctx = contextOf.call(this, context);
		const items = ctx.getInputData();
		const results = [];

		for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
			results.push(await runItem(ctx, itemIndex));
		}

		return [results];
	}
}

module.exports = { PiWeb };
