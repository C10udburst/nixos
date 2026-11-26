/**
 * system-prompt — strip the harness docs section from the default system prompt.
 *
 * The `<docs>` block points the model at pi's own documentation tree, most of
 * which is about how to build pi extensions (extension docs, examples, the TUI
 * guide, SDK notes). That content is dead weight for coding work: it biases the
 * agent toward harness questions and wastes tokens on every request.
 *
 * This extension removes the whole `<docs>...</docs>` section, plus the
 * standalone "Pi can create extensions" banner some builds prepend, from every
 * run via `before_agent_start`. Hosts whose prompt has no such section (custom
 * system prompts, other builds) are left untouched, so the handler is a no-op
 * there rather than a corruption risk.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function stripDocs(prompt: string): string {
    const lines = prompt.split(/\r?\n/);
    const kept: string[] = [];
    let inDocs = false;

    for (const line of lines) {
        if (!inDocs) {
            const openIdx = line.indexOf("<docs>");
            if (openIdx !== -1) {
                inDocs = true;
                const beforeOpen = line.slice(0, openIdx);
                const afterOpen = line.slice(openIdx + "<docs>".length);
                const closeIdx = afterOpen.indexOf("</docs>");

                if (closeIdx !== -1) {
                    inDocs = false;
                    const remainder = beforeOpen + afterOpen.slice(closeIdx + "</docs>".length);
                    if (remainder.trim() !== "") kept.push(remainder);
                } else if (beforeOpen.trim() !== "") {
                    kept.push(beforeOpen);
                }
                continue;
            }

            kept.push(line);
        } else {
            const closeIdx = line.indexOf("</docs>");
            if (closeIdx !== -1) {
                inDocs = false;
                const afterClose = line.slice(closeIdx + "</docs>".length);
                if (afterClose.trim() !== "") kept.push(afterClose);
            }
        }
    }

    return kept.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

export default function (pi: ExtensionAPI) {
    pi.on("before_agent_start", (event) => {
        const original = event.systemPrompt;
        if (!original) return undefined;

        const stripped = stripDocs(original);
        if (stripped === original) return undefined;

        return { systemPrompt: stripped };
    });
}
