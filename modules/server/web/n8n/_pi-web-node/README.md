# n8n-nodes-pi-web

An n8n node for [Pi Web](https://github.com/agegr/pi-web): it opens a pi session in a
directory of your choosing, arms the EVO-X2 lease with `/enqueue`, and then sends the
prompt that has to wait behind that gate.

Built into the flake as `features.server.web.n8n.piWeb` and handed to n8n through
`N8N_CUSTOM_EXTENSIONS`, so nothing is installed from npm. `default.nix` in this folder
packages it into `$out/lib/node_modules/n8n-nodes-pi-web`, which is the layout the
`services.n8n` module's linkFarm links, and `features.server.web.n8n.nodes` takes further
packages the same way.

## Endpoints it calls

| Step | Call |
| --- | --- |
| create the session | `POST /api/agent/new` with `{ cwd, type: "ensure_session" }` |
| send the command | `POST /api/agent/<sessionId>` with `{ type: "prompt", message: "/enqueue <allotment> <comment>" }` |
| send the prompt | `POST /api/agent/<sessionId>` with `{ type: "prompt", message: "<prompt>" }` |

Slash commands go out as prompts, which is what the web composer does, so they reach the
commands registered in the agent directory of that instance (`/enqueue` comes from the
queue extension in `modules/shell/utils/llm/pi/extensions/_queue.ts`).

The order is the point: `/enqueue` arms the gate and returns while it chases the slot in
the background, so the prompt that follows queues behind the lease instead of spending
provider requests before the machine is ours.

## Node parameters

- **Action** — `Enqueue and Prompt` (default), `Prompt Only`, `Command Only`, `Create Session Only`
- **Working Directory** — directory on the Pi Web host the session starts in
- **Allotment** — lease length for `/enqueue`: `90`, `45m`, `1h`, `1h30`, or `status`
- **Comment** — what the lease is for
- **Command Override** — sent instead of the assembled `/enqueue` line, e.g. `/enqueue status`
- **Prompt** — the instruction the session gets
- **Options** — `Provider` + `Model ID` for the new session, `Timeout (ms)`

Every field takes n8n expressions, so a schedule trigger can drive the directory, the
allotment, the comment and the prompt from the incoming item.

One item out per item in:

```json
{
  "sessionId": "01J…",
  "sessionUrl": "https://pi.brix0.wilkins.pl.eu.org/?session=01J…",
  "directory": "/home/cloudburst/nixos",
  "action": "enqueuePrompt",
  "command": "/enqueue 1h30 rebasing the flake",
  "prompt": "push the flake after the rebase",
  "commandResponse": null,
  "promptResponse": { "queued": true },
  "model": { "provider": "evo-x2", "modelId": "mimo-v2.6-flash-mopd" },
  "thinkingLevel": "medium"
}
```

## Credential

`Pi Web API` holds the base URL and the password. Pi Web answers unauthenticated unless
it runs with `PI_WEB_PASSWORD`, in which case every `/api` route takes that password in
HTTP Basic with any username.

The hostname also has to be one Pi Web accepts: loopback, an IP literal, or a name in
`PI_WEB_ALLOWED_HOSTS` on the machine serving it. `features.shell.utils.llm.pi.web` on
zeph already lists `pi.brix0.wilkins.pl.eu.org`.

No browser headers are sent: Pi Web rejects API requests marked `Sec-Fetch-Site:
cross-site` and compares `Origin` against `Host`, and a server-to-server call with
neither header is the shape that always passes.
