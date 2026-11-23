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

/** The XML-wrapped docs section, tolerant of surrounding whitespace. */
const DOCS_SECTION = /\s*<docs>[\s\S]*?<\/docs>/gi;

/** "> Pi can create extensions. Ask it to build one for your use case." */
const EXTENSION_BANNER = /^\s*>?\s*Pi can create extensions[^\n]*\n?/im;

export default function (pi: ExtensionAPI) {
    pi.on("before_agent_start", (event) => {
        const original = event.systemPrompt;
        if (!original) return undefined;

        const stripped = original
            .replace(DOCS_SECTION, "")
            .replace(EXTENSION_BANNER, "")
            .trim();

        if (stripped === original) return undefined;
        return { systemPrompt: stripped };
    });
}
