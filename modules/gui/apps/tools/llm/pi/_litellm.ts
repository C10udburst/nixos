/**
 * LiteLLM Gateway Extension for Pi
 *
 * Adds on-demand model browsing and management for a LiteLLM proxy gateway.
 *
 * Features:
 * - /litellm add: opens a Ranger/tree-like TUI browser that fetches /model/info,
 *   hierarchically organizes models by "/" segments, shows detailed inspection,
 *   and toggles adding models to Pi's model dropdown.
 * - /litellm remove <model-id>: removes a model from selection.
 * - /litellm list: lists currently added models.
 * - Persistent state stored in ~/.pi/agent/litellm-models.json (separate from
 *   read-only home-manager models.json).
 * - Catalog cache stored in ~/.pi/agent/litellm-cache.json to avoid multi-second
 *   re-fetches on every open.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ProviderChatModelConfig,
  Theme,
} from "@earendil-works/pi-coding-agent";
import {
  matchesKey,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";

// ------------------------------------------------------------------ Config & Paths

const DEFAULT_LITELLM_BASE = "https://llm.brix0.wilkins.pl.eu.org";
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour cache validity

function getLiteLLMBase(): string {
  return (
    process.env.LITELLM_API_BASE ||
    process.env.LITELLM_BASE_URL ||
    DEFAULT_LITELLM_BASE
  ).replace(/\/+$/, "");
}

function getLiteLLMKey(): string {
  return process.env.LITELLM_API_KEY || "none";
}

function resolveAgentDir(): string {
  if (process.env.PI_CODING_AGENT_DIR) {
    return process.env.PI_CODING_AGENT_DIR;
  }
  return join(homedir(), ".pi", "agent");
}

function getStateFilePath(): string {
  return join(resolveAgentDir(), "litellm-models.json");
}

function getCacheFilePath(): string {
  return join(resolveAgentDir(), "litellm-cache.json");
}

// ------------------------------------------------------------------ Types

interface SavedModel {
  id: string;
  name: string;
  contextWindow: number;
  maxTokens: number;
  reasoning: boolean;
  input: ("text" | "image")[];
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
  provider: string;
  description: string;
  addedAt: string;
}

interface RawModelItem {
  model_name?: string;
  id?: string;
  litellm_params?: {
    model?: string;
    api_base?: string;
    [key: string]: unknown;
  };
  model_info?: {
    id?: string;
    description?: string;
    input_modalities?: string[];
    modalities?: string[];
    max_input_tokens?: number;
    max_context_length?: number;
    context_window_size?: number;
    max_output_tokens?: number;
    max_tokens?: number;
    supports_vision?: boolean;
    supports_reasoning?: boolean;
    input_cost_per_token?: number;
    output_cost_per_token?: number;
    cache_read_input_token_cost?: number;
    cache_creation_input_token_cost?: number;
    litellm_provider?: string;
    [key: string]: unknown;
  };
}

interface TreeModelNode {
  name: string;
  fullId: string;
  item: RawModelItem;
}

interface TreeFolderNode {
  name: string;
  path: string[];
  subfolders: Map<string, TreeFolderNode>;
  models: TreeModelNode[];
}

// ------------------------------------------------------------------ State Persistence

function loadSavedModels(): Map<string, SavedModel> {
  const filePath = getStateFilePath();
  const map = new Map<string, SavedModel>();
  if (!existsSync(filePath)) return map;

  try {
    const raw = JSON.parse(readFileSync(filePath, "utf-8"));
    const list: SavedModel[] = Array.isArray(raw)
      ? raw
      : raw.models
        ? Array.isArray(raw.models)
          ? raw.models
          : Object.values(raw.models)
        : [];
    for (const m of list) {
      if (m && m.id) {
        map.set(m.id, m);
      }
    }
  } catch (err) {
    console.error("Failed to read litellm-models.json:", err);
  }
  return map;
}

function saveSavedModels(models: Map<string, SavedModel>): void {
  const dir = resolveAgentDir();
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  const filePath = getStateFilePath();
  const data = {
    version: 1,
    updatedAt: new Date().toISOString(),
    models: Array.from(models.values()),
  };
  writeFileSync(filePath, JSON.stringify(data, null, 2), "utf-8");
}

function syncProvider(
  pi: ExtensionAPI,
  models: Map<string, SavedModel>,
  base: string,
  apiKey: string
): void {
  const modelList: ProviderChatModelConfig[] = Array.from(models.values()).map(
    (m) => ({
      type: "chat",
      id: m.id,
      name: m.name || m.id,
      api: "openai-completions",
      contextWindow: m.contextWindow || 128000,
      maxTokens: m.maxTokens || 8192,
      reasoning: m.reasoning ?? false,
      input: m.input || ["text"],
      cost: m.cost || { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      compat: {
        supportsDeveloperRole: false,
        supportsReasoningEffort: true,
      },
    })
  );

  if (modelList.length > 0) {
    pi.registerProvider("litellm", {
      name: "LiteLLM Gateway",
      baseUrl: `${base.replace(/\/+$/, "")}/v1`,
      api: "openai-completions",
      apiKey: apiKey,
      compat: {
        supportsDeveloperRole: false,
        supportsReasoningEffort: true,
      },
      models: modelList,
    });
  } else {
    pi.unregisterProvider("litellm");
  }
}

// ------------------------------------------------------------------ Model Helpers

function buildSavedModel(item: RawModelItem): SavedModel {
  const id = item.model_name || item.id || item.model_info?.id || "unknown";
  const info = item.model_info || {};

  const contextWindow = Math.max(
    8192,
    info.max_input_tokens ||
      info.max_context_length ||
      info.context_window_size ||
      128000
  );

  const maxTokens = Math.max(
    4096,
    info.max_output_tokens || info.max_tokens || 8192
  );

  const supportsVision = Boolean(
    info.supports_vision ||
      (Array.isArray(info.input_modalities) &&
        info.input_modalities.includes("image")) ||
      (Array.isArray(info.modalities) && info.modalities.includes("image"))
  );

  const inputModalities: ("text" | "image")[] = supportsVision
    ? ["text", "image"]
    : ["text"];

  const idLower = id.toLowerCase();
  const supportsReasoning = Boolean(
    info.supports_reasoning ||
      idLower.includes("r1") ||
      idLower.includes("thinking") ||
      idLower.includes("reasoning")
  );

  const inputCost = (info.input_cost_per_token || 0) * 1_000_000;
  const outputCost = (info.output_cost_per_token || 0) * 1_000_000;
  const cacheReadCost = (info.cache_read_input_token_cost || 0) * 1_000_000;
  const cacheWriteCost =
    (info.cache_creation_input_token_cost || 0) * 1_000_000;

  const provider =
    info.litellm_provider || item.litellm_params?.model || "openai";
  const description = info.description || "";

  return {
    id,
    name: id,
    contextWindow,
    maxTokens,
    reasoning: supportsReasoning,
    input: inputModalities,
    cost: {
      input: inputCost,
      output: outputCost,
      cacheRead: cacheReadCost,
      cacheWrite: cacheWriteCost,
    },
    provider,
    description,
    addedAt: new Date().toISOString(),
  };
}

function formatTokens(n: number): string {
  if (n >= 1_000_000) {
    return `${(n / 1_000_000).toFixed(n % 1_000_000 === 0 ? 0 : 1)}M (${n.toLocaleString()})`;
  }
  if (n >= 1_000) {
    return `${Math.round(n / 1_000)}k (${n.toLocaleString()})`;
  }
  return n.toLocaleString();
}

function formatCost(cost: SavedModel["cost"]): string {
  if (!cost || (cost.input === 0 && cost.output === 0)) {
    return "Free / Default";
  }
  return `$${cost.input.toFixed(3)} in / $${cost.output.toFixed(3)} out per 1M`;
}

// ------------------------------------------------------------------ Tree Builder

function buildTree(items: RawModelItem[]): TreeFolderNode {
  const root: TreeFolderNode = {
    name: "",
    path: [],
    subfolders: new Map(),
    models: [],
  };

  const seenIds = new Set<string>();

  for (const item of items) {
    const rawName = item.model_name || item.id || item.model_info?.id;
    if (!rawName) continue;
    if (seenIds.has(rawName)) continue;
    seenIds.add(rawName);

    const parts = rawName.split("/").filter(Boolean);
    if (parts.length === 0) continue;

    let curr = root;
    for (let i = 0; i < parts.length - 1; i++) {
      const seg = parts[i];
      if (!curr.subfolders.has(seg)) {
        curr.subfolders.set(seg, {
          name: seg,
          path: [...curr.path, seg],
          subfolders: new Map(),
          models: [],
        });
      }
      curr = curr.subfolders.get(seg)!;
    }

    const leafName = parts[parts.length - 1];
    curr.models.push({
      name: leafName,
      fullId: rawName,
      item,
    });
  }

  // Sort subfolders and models alphabetically at all levels
  function sortNode(node: TreeFolderNode) {
    node.models.sort((a, b) => a.name.localeCompare(b.name));
    for (const sub of node.subfolders.values()) {
      sortNode(sub);
    }
  }
  sortNode(root);

  return root;
}

function countTotalModels(node: TreeFolderNode): number {
  let count = node.models.length;
  for (const sub of node.subfolders.values()) {
    count += countTotalModels(sub);
  }
  return count;
}

// ------------------------------------------------------------------ Catalog Fetcher

let inMemoryCatalogCache: RawModelItem[] | null = null;
let inMemoryCatalogTime = 0;

async function fetchCatalog(
  base: string,
  apiKey: string,
  signal?: AbortSignal,
  forceRefresh = false
): Promise<RawModelItem[]> {
  const now = Date.now();
  if (
    !forceRefresh &&
    inMemoryCatalogCache &&
    now - inMemoryCatalogTime < CACHE_TTL_MS
  ) {
    return inMemoryCatalogCache;
  }

  const cachePath = getCacheFilePath();
  if (!forceRefresh && existsSync(cachePath)) {
    try {
      const cached = JSON.parse(readFileSync(cachePath, "utf-8"));
      if (cached && cached.timestamp && now - cached.timestamp < CACHE_TTL_MS) {
        if (Array.isArray(cached.data)) {
          inMemoryCatalogCache = cached.data;
          inMemoryCatalogTime = cached.timestamp;
          return cached.data;
        }
      }
    } catch {
      // Ignore cache read errors and fetch fresh
    }
  }

  const headers: Record<string, string> = {
    Accept: "application/json",
  };
  if (apiKey && apiKey !== "none") {
    headers.Authorization = `Bearer ${apiKey}`;
  }

  // Try /model/info first, then /models/info as fallback
  const endpoints = [`${base}/model/info`, `${base}/models/info`];
  let lastError: Error | null = null;

  for (const endpoint of endpoints) {
    try {
      const res = await fetch(endpoint, {
        method: "GET",
        headers,
        signal,
      });
      if (!res.ok) {
        lastError = new Error(`HTTP ${res.status}: ${res.statusText}`);
        continue;
      }
      const data = (await res.json()) as { data?: RawModelItem[] };
      if (data && Array.isArray(data.data)) {
        inMemoryCatalogCache = data.data;
        inMemoryCatalogTime = now;
        try {
          const dir = resolveAgentDir();
          if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
          writeFileSync(
            cachePath,
            JSON.stringify({ timestamp: now, data: data.data }),
            "utf-8"
          );
        } catch {
          // Ignore cache write failure
        }
        return data.data;
      }
    } catch (err: unknown) {
      if (signal?.aborted) throw err;
      lastError = err instanceof Error ? err : new Error(String(err));
    }
  }

  throw lastError || new Error("Failed to fetch models from LiteLLM gateway");
}

// ------------------------------------------------------------------ Text Formatting Helper

function padRight(str: string, targetWidth: number): string {
  const currentWidth = visibleWidth(str);
  if (currentWidth >= targetWidth) {
    return truncateToWidth(str, targetWidth);
  }
  return str + " ".repeat(targetWidth - currentWidth);
}

// ------------------------------------------------------------------ Browser Component

interface ListItem {
  type: "back" | "folder" | "model";
  name: string;
  label: string;
  badge?: string;
  folder?: TreeFolderNode;
  model?: TreeModelNode;
}

class LiteLLMBrowserComponent {
  private tui: { requestRender: () => void };
  private theme: Theme;
  private onDone: () => void;
  private pi: ExtensionAPI;
  private base: string;
  private apiKey: string;

  private savedModels: Map<string, SavedModel>;
  private rootTree: TreeFolderNode | null = null;
  private allModelsFlat: TreeModelNode[] = [];

  // Navigation state
  private currentPath: string[] = [];
  private selectedIndex = 0;
  private scrollOffset = 0;

  // Search state
  private inSearchMode = false;
  private searchQuery = "";
  private searchResults: TreeModelNode[] = [];

  // Loading / Error state
  private isLoading = true;
  private loadStatusText = "Connecting to LiteLLM gateway...";
  private loadError: string | null = null;
  private spinnerIndex = 0;
  private spinnerTimer?: NodeJS.Timeout;
  private abortController = new AbortController();

  constructor(
    tui: { requestRender: () => void },
    theme: Theme,
    onDone: () => void,
    pi: ExtensionAPI,
    savedModels: Map<string, SavedModel>,
    base: string,
    apiKey: string
  ) {
    this.tui = tui;
    this.theme = theme;
    this.onDone = onDone;
    this.pi = pi;
    this.savedModels = savedModels;
    this.base = base;
    this.apiKey = apiKey;

    this.startLoading();
  }

  private startLoading(forceRefresh = false) {
    this.isLoading = true;
    this.loadError = null;
    this.loadStatusText = forceRefresh
      ? "Refreshing catalog from LiteLLM gateway..."
      : "Fetching models from LiteLLM gateway...";
    this.abortController = new AbortController();

    const spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
    if (this.spinnerTimer) clearInterval(this.spinnerTimer);
    this.spinnerTimer = setInterval(() => {
      this.spinnerIndex = (this.spinnerIndex + 1) % spinnerFrames.length;
      this.tui.requestRender();
    }, 90);

    fetchCatalog(
      this.base,
      this.apiKey,
      this.abortController.signal,
      forceRefresh
    )
      .then((items) => {
        if (this.spinnerTimer) clearInterval(this.spinnerTimer);
        this.rootTree = buildTree(items);
        this.allModelsFlat = [];
        const collectFlat = (node: TreeFolderNode) => {
          this.allModelsFlat.push(...node.models);
          for (const sub of node.subfolders.values()) {
            collectFlat(sub);
          }
        };
        collectFlat(this.rootTree);

        this.isLoading = false;
        this.selectedIndex = 0;
        this.scrollOffset = 0;
        this.tui.requestRender();
      })
      .catch((err: unknown) => {
        if (this.spinnerTimer) clearInterval(this.spinnerTimer);
        if (this.abortController.signal.aborted) {
          this.onDone();
          return;
        }
        this.isLoading = false;
        this.loadError = err instanceof Error ? err.message : String(err);
        this.tui.requestRender();
      });
  }

  dispose(): void {
    if (this.spinnerTimer) {
      clearInterval(this.spinnerTimer);
    }
    this.abortController.abort();
  }

  invalidate(): void {
    // Dynamic component renders directly
  }

  private getCurrentFolder(): TreeFolderNode {
    if (!this.rootTree) {
      return {
        name: "",
        path: [],
        subfolders: new Map(),
        models: [],
      };
    }
    let curr = this.rootTree;
    for (const seg of this.currentPath) {
      if (curr.subfolders.has(seg)) {
        curr = curr.subfolders.get(seg)!;
      } else {
        break;
      }
    }
    return curr;
  }

  private getCurrentItems(): ListItem[] {
    if (this.inSearchMode) {
      return this.searchResults.map((m) => {
        const isAdded = this.savedModels.has(m.fullId);
        return {
          type: "model",
          name: m.name,
          label: m.fullId,
          badge: isAdded ? "✓ Added" : undefined,
          model: m,
        };
      });
    }

    const folder = this.getCurrentFolder();
    const items: ListItem[] = [];

    if (this.currentPath.length > 0) {
      items.push({
        type: "back",
        name: "..",
        label: ".. (parent folder)",
      });
    }

    for (const sub of folder.subfolders.values()) {
      const count = countTotalModels(sub);
      items.push({
        type: "folder",
        name: sub.name,
        label: `${sub.name}/`,
        badge: `${count}`,
        folder: sub,
      });
    }

    for (const mod of folder.models) {
      const isAdded = this.savedModels.has(mod.fullId);
      items.push({
        type: "model",
        name: mod.name,
        label: mod.name,
        badge: isAdded ? "✓ Added" : undefined,
        model: mod,
      });
    }

    return items;
  }

  private updateSearch() {
    if (!this.searchQuery.trim()) {
      this.searchResults = [];
      return;
    }
    const q = this.searchQuery.toLowerCase();
    this.searchResults = this.allModelsFlat.filter((m) =>
      m.fullId.toLowerCase().includes(q)
    );
  }

  private toggleModel(mod: TreeModelNode) {
    const isAdded = this.savedModels.has(mod.fullId);
    if (isAdded) {
      this.savedModels.delete(mod.fullId);
    } else {
      const saved = buildSavedModel(mod.item);
      this.savedModels.set(mod.fullId, saved);
    }
    saveSavedModels(this.savedModels);
    syncProvider(this.pi, this.savedModels, this.base, this.apiKey);
    this.tui.requestRender();
  }

  handleInput(data: string): void {
    if (this.isLoading) {
      if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
        this.abortController.abort();
        this.onDone();
      }
      return;
    }

    if (this.loadError) {
      if (
        matchesKey(data, "r") ||
        matchesKey(data, "return") ||
        matchesKey(data, "enter")
      ) {
        this.startLoading(true);
      } else if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
        this.onDone();
      }
      return;
    }

    const items = this.getCurrentItems();

    // ---------------- Search Mode Input
    if (this.inSearchMode) {
      if (matchesKey(data, "escape")) {
        this.inSearchMode = false;
        this.searchQuery = "";
        this.selectedIndex = 0;
        this.scrollOffset = 0;
        this.tui.requestRender();
        return;
      }
      if (matchesKey(data, "return") || matchesKey(data, "enter")) {
        const item = items[this.selectedIndex];
        if (item?.model) {
          this.toggleModel(item.model);
        }
        return;
      }
      if (matchesKey(data, "up") || matchesKey(data, "ctrl+p")) {
        if (this.selectedIndex > 0) this.selectedIndex--;
        this.tui.requestRender();
        return;
      }
      if (matchesKey(data, "down") || matchesKey(data, "ctrl+n")) {
        if (this.selectedIndex < items.length - 1) this.selectedIndex++;
        this.tui.requestRender();
        return;
      }
      if (matchesKey(data, "backspace")) {
        if (this.searchQuery.length > 0) {
          this.searchQuery = this.searchQuery.slice(0, -1);
          this.updateSearch();
          this.selectedIndex = 0;
          this.scrollOffset = 0;
          this.tui.requestRender();
        } else {
          this.inSearchMode = false;
          this.selectedIndex = 0;
          this.scrollOffset = 0;
          this.tui.requestRender();
        }
        return;
      }

      // Append printable character
      if (data.length === 1 && data >= " ") {
        this.searchQuery += data;
        this.updateSearch();
        this.selectedIndex = 0;
        this.scrollOffset = 0;
        this.tui.requestRender();
        return;
      }
      return;
    }

    // ---------------- Tree Navigation Mode Input
    if (matchesKey(data, "escape") || matchesKey(data, "q")) {
      this.onDone();
      return;
    }

    if (data === "/" || matchesKey(data, "ctrl+f")) {
      this.inSearchMode = true;
      this.searchQuery = "";
      this.updateSearch();
      this.selectedIndex = 0;
      this.scrollOffset = 0;
      this.tui.requestRender();
      return;
    }

    if (data === "r" || data === "R") {
      this.startLoading(true);
      return;
    }

    if (
      matchesKey(data, "up") ||
      matchesKey(data, "k") ||
      matchesKey(data, "ctrl+p")
    ) {
      if (this.selectedIndex > 0) {
        this.selectedIndex--;
      }
      this.tui.requestRender();
      return;
    }

    if (
      matchesKey(data, "down") ||
      matchesKey(data, "j") ||
      matchesKey(data, "ctrl+n")
    ) {
      if (this.selectedIndex < items.length - 1) {
        this.selectedIndex++;
      }
      this.tui.requestRender();
      return;
    }

    if (matchesKey(data, "pageup")) {
      this.selectedIndex = Math.max(0, this.selectedIndex - 8);
      this.tui.requestRender();
      return;
    }

    if (matchesKey(data, "pagedown")) {
      this.selectedIndex = Math.min(items.length - 1, this.selectedIndex + 8);
      this.tui.requestRender();
      return;
    }

    if (matchesKey(data, "home")) {
      this.selectedIndex = 0;
      this.tui.requestRender();
      return;
    }

    if (matchesKey(data, "end")) {
      this.selectedIndex = Math.max(0, items.length - 1);
      this.tui.requestRender();
      return;
    }

    // Go back with Left, h, or Backspace
    if (
      matchesKey(data, "left") ||
      matchesKey(data, "h") ||
      matchesKey(data, "backspace")
    ) {
      if (this.currentPath.length > 0) {
        const lastFolder = this.currentPath.pop();
        const parentItems = this.getCurrentItems();
        const prevIndex = parentItems.findIndex(
          (it) => it.type === "folder" && it.name === lastFolder
        );
        this.selectedIndex = prevIndex >= 0 ? prevIndex : 0;
        this.scrollOffset = 0;
        this.tui.requestRender();
      }
      return;
    }

    // Enter or Right or l: open folder or toggle model
    if (
      matchesKey(data, "return") ||
      matchesKey(data, "enter") ||
      matchesKey(data, "right") ||
      matchesKey(data, "l") ||
      matchesKey(data, "space") ||
      data === "a" ||
      data === "A"
    ) {
      const item = items[this.selectedIndex];
      if (!item) return;

      if (item.type === "back") {
        if (this.currentPath.length > 0) {
          const lastFolder = this.currentPath.pop();
          const parentItems = this.getCurrentItems();
          const prevIndex = parentItems.findIndex(
            (it) => it.type === "folder" && it.name === lastFolder
          );
          this.selectedIndex = prevIndex >= 0 ? prevIndex : 0;
          this.scrollOffset = 0;
          this.tui.requestRender();
        }
      } else if (item.type === "folder" && item.folder) {
        this.currentPath.push(item.folder.name);
        this.selectedIndex = 0;
        this.scrollOffset = 0;
        this.tui.requestRender();
      } else if (item.type === "model" && item.model) {
        this.toggleModel(item.model);
      }
    }
  }

  render(width: number): string[] {
    const lines: string[] = [];
    const th = this.theme;
    const contentWidth = Math.max(40, width - 4);

    // ---------------- Loading View
    if (this.isLoading) {
      const spinnerFrames = [
        "⠋",
        "⠙",
        "⠹",
        "⠸",
        "⠼",
        "⠴",
        "⠦",
        "⠧",
        "⠇",
        "⠏",
      ];
      const frame = spinnerFrames[this.spinnerIndex];
      lines.push("");
      lines.push(
        th.fg(
          "borderMuted",
          "┌─ " +
            th.fg("accent", th.bold("LiteLLM Models")) +
            " " +
            "─".repeat(Math.max(0, width - 22)) +
            "┐"
        )
      );
      lines.push(
        th.fg("borderMuted", "│") +
          " ".repeat(Math.max(0, width - 2)) +
          th.fg("borderMuted", "│")
      );
      const msg = `  ${th.fg("accent", frame)} ${th.fg("text", this.loadStatusText)}`;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            padRight(msg, width - 2) +
            th.fg("borderMuted", "│"),
          width
        )
      );
      const note = `  ${th.fg("dim", "(fetching model catalog from gateway, this may take several seconds)")}`;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            padRight(note, width - 2) +
            th.fg("borderMuted", "│"),
          width
        )
      );
      lines.push(
        th.fg("borderMuted", "│") +
          " ".repeat(Math.max(0, width - 2)) +
          th.fg("borderMuted", "│")
      );
      const hint = `  ${th.fg("dim", "Press " + th.fg("accent", "Escape") + " to cancel")}`;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            padRight(hint, width - 2) +
            th.fg("borderMuted", "│"),
          width
        )
      );
      lines.push(
        th.fg("borderMuted", "└" + "─".repeat(Math.max(0, width - 2)) + "┘")
      );
      lines.push("");
      return lines;
    }

    // ---------------- Error View
    if (this.loadError) {
      lines.push("");
      lines.push(
        th.fg(
          "borderMuted",
          "┌─ " +
            th.fg("error", th.bold("LiteLLM Gateway Error")) +
            " " +
            "─".repeat(Math.max(0, width - 27)) +
            "┐"
        )
      );
      lines.push(
        th.fg("borderMuted", "│") +
          " ".repeat(Math.max(0, width - 2)) +
          th.fg("borderMuted", "│")
      );
      const errLine = `  ${th.fg("error", "Failed to reach: ")} ${th.fg("text", this.base)}`;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            padRight(errLine, width - 2) +
            th.fg("borderMuted", "│"),
          width
        )
      );
      const detailLine = `  ${th.fg("dim", this.loadError)}`;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            padRight(detailLine, width - 2) +
            th.fg("borderMuted", "│"),
          width
        )
      );
      lines.push(
        th.fg("borderMuted", "│") +
          " ".repeat(Math.max(0, width - 2)) +
          th.fg("borderMuted", "│")
      );
      const actionLine = `  ${th.fg("dim", "Press " + th.fg("accent", "r") + " to retry, or " + th.fg("accent", "Escape") + " to close")}`;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            padRight(actionLine, width - 2) +
            th.fg("borderMuted", "│"),
          width
        )
      );
      lines.push(
        th.fg("borderMuted", "└" + "─".repeat(Math.max(0, width - 2)) + "┘")
      );
      lines.push("");
      return lines;
    }

    // ---------------- Ranger/Tree Browser View
    const items = this.getCurrentItems();
    const viewportHeight = 15;

    // Adjust scrolling window
    if (this.selectedIndex < this.scrollOffset) {
      this.scrollOffset = this.selectedIndex;
    } else if (this.selectedIndex >= this.scrollOffset + viewportHeight) {
      this.scrollOffset = this.selectedIndex - viewportHeight + 1;
    }

    // Calculate columns
    const leftWidth = Math.max(
      26,
      Math.min(42, Math.floor(contentWidth * 0.44))
    );
    const rightWidth = Math.max(30, contentWidth - leftWidth - 3);

    // 1. Header Line
    const titleText = th.fg("accent", th.bold(" LiteLLM Models "));
    const addedCount = this.savedModels.size;
    const countBadge = th.fg(
      "dim",
      `(${addedCount} in dropdown) `
    );
    const modeBadge = this.inSearchMode
      ? th.fg("warning", "[Search] ")
      : th.fg("dim", "[Tree] ");
    const headerHelp = th.fg(
      "dim",
      "[/] Search  [Esc] Close "
    );
    const topDashes = Math.max(
      0,
      width -
        visibleWidth(titleText) -
        visibleWidth(countBadge) -
        visibleWidth(modeBadge) -
        visibleWidth(headerHelp) -
        6
    );

    lines.push("");
    lines.push(
      th.fg("borderMuted", "┌─") +
        titleText +
        countBadge +
        modeBadge +
        th.fg("borderMuted", "─".repeat(topDashes)) +
        headerHelp +
        th.fg("borderMuted", "─┐")
    );

    // 2. Breadcrumbs / Search query line
    let subHeader = "";
    if (this.inSearchMode) {
      subHeader = `  ${th.fg("accent", "🔍 Search: ")}${th.fg("text", this.searchQuery)}${th.fg("dim", "█")}${th.fg("dim", ` (${items.length} matches)`)}`;
    } else {
      const pathStr = "/" + this.currentPath.join("/");
      subHeader = `  ${th.fg("dim", "Path: ")}${th.fg("accent", pathStr)} ${th.fg("dim", `(${items.length} items)`)}`;
    }
    lines.push(
      truncateToWidth(
        th.fg("borderMuted", "│") +
          padRight(subHeader, width - 2) +
          th.fg("borderMuted", "│"),
        width
      )
    );

    // 3. Middle Separator
    lines.push(
      th.fg(
        "borderMuted",
        "├" +
          "─".repeat(leftWidth + 2) +
          "┬" +
          "─".repeat(Math.max(0, width - leftWidth - 5)) +
          "┤"
      )
    );

    // Prepare Left Column Lines
    const leftRows: string[] = [];
    const visibleItems = items.slice(
      this.scrollOffset,
      this.scrollOffset + viewportHeight
    );

    if (items.length === 0) {
      leftRows.push(
        padRight(
          this.inSearchMode
            ? `  ${th.fg("dim", "No matching models")}`
            : `  ${th.fg("dim", "Folder is empty")}`,
          leftWidth
        )
      );
    } else {
      for (let i = 0; i < visibleItems.length; i++) {
        const item = visibleItems[i];
        const actualIndex = this.scrollOffset + i;
        const isSelected = actualIndex === this.selectedIndex;

        const cursor = isSelected ? th.fg("accent", "▶ ") : "  ";
        let icon = "";
        let nameStyled = "";
        let badgeStyled = "";

        if (item.type === "back") {
          icon = th.fg("dim", "📁 ");
          nameStyled = th.fg(isSelected ? "accent" : "dim", item.label);
        } else if (item.type === "folder") {
          icon = th.fg("accent", "📁 ");
          nameStyled = th.fg(isSelected ? "accent" : "text", item.label);
          if (item.badge) {
            badgeStyled = " " + th.fg("dim", `(${item.badge})`);
          }
        } else {
          const isAdded = item.badge?.includes("Added");
          icon = isAdded ? th.fg("success", "✓ ") : th.fg("dim", "◆ ");
          nameStyled = th.fg(
            isSelected ? "accent" : isAdded ? "success" : "text",
            item.label
          );
        }

        const fullRow = `${cursor}${icon}${nameStyled}${badgeStyled}`;
        leftRows.push(padRight(fullRow, leftWidth));
      }
    }

    // Pad left column to viewport height
    while (leftRows.length < viewportHeight) {
      leftRows.push(" ".repeat(leftWidth));
    }

    // Prepare Right Column Lines (Inspection Pane)
    const rightRows: string[] = [];
    const selectedItem = items[this.selectedIndex];

    if (!selectedItem) {
      rightRows.push(th.fg("dim", "No item selected"));
    } else if (selectedItem.type === "back") {
      rightRows.push(th.fg("accent", th.bold("Parent Folder")));
      rightRows.push("");
      rightRows.push(th.fg("dim", "Press Enter or ← to navigate up."));
    } else if (selectedItem.type === "folder" && selectedItem.folder) {
      const f = selectedItem.folder;
      rightRows.push(th.fg("accent", th.bold(`📁 ${f.name}`)));
      rightRows.push(th.fg("dim", `Path: /${f.path.join("/")}`));
      rightRows.push("");
      rightRows.push(
        th.fg(
          "muted",
          `Contains: ${f.subfolders.size} subfolders, ${f.models.length} direct models`
        )
      );
      rightRows.push(
        th.fg("dim", `Total models recursively: ${countTotalModels(f)}`)
      );
      rightRows.push("");
      rightRows.push(th.fg("dim", "Preview of contents:"));
      const sample = [
        ...Array.from(f.subfolders.keys()).map((k) => `📁 ${k}/`),
        ...f.models.map((m) => `◆ ${m.name}`),
      ].slice(0, 5);
      for (const s of sample) {
        rightRows.push(`  ${th.fg("dim", s)}`);
      }
      rightRows.push("");
      rightRows.push(th.fg("accent", "Press Enter or → to open folder"));
    } else if (selectedItem.type === "model" && selectedItem.model) {
      const m = selectedItem.model;
      const isAdded = this.savedModels.has(m.fullId);
      const saved = isAdded
        ? this.savedModels.get(m.fullId)!
        : buildSavedModel(m.item);

      rightRows.push(th.fg("accent", th.bold(m.name)));
      rightRows.push(th.fg("dim", "ID: ") + th.fg("muted", m.fullId));
      rightRows.push(
        th.fg("dim", "Status: ") +
          (isAdded
            ? th.fg("success", "● Added to Pi Dropdown")
            : th.fg("dim", "○ Not added"))
      );
      rightRows.push(
        th.fg("dim", "Context Window: ") +
          th.fg("text", formatTokens(saved.contextWindow))
      );
      rightRows.push(
        th.fg("dim", "Max Output: ") +
          th.fg("text", formatTokens(saved.maxTokens))
      );
      rightRows.push(
        th.fg("dim", "Reasoning: ") +
          (saved.reasoning ? th.fg("success", "Yes") : th.fg("dim", "No"))
      );
      rightRows.push(
        th.fg("dim", "Vision / Images: ") +
          (saved.input.includes("image")
            ? th.fg("success", "Yes (vision)")
            : th.fg("dim", "No (text only)"))
      );
      rightRows.push(
        th.fg("dim", "Pricing: ") + th.fg("text", formatCost(saved.cost))
      );
      rightRows.push(
        th.fg("dim", "Provider: ") + th.fg("text", saved.provider)
      );

      if (saved.description) {
        rightRows.push(
          th.fg("dim", "Description: ") +
            th.fg(
              "dim",
              truncateToWidth(
                saved.description.replace(/\n/g, " "),
                rightWidth - 14
              )
            )
        );
      }
      rightRows.push("");
      rightRows.push(
        isAdded
          ? th.fg("warning", "[Enter / Space] Remove from Dropdown")
          : th.fg("success", "[Enter / Space] Add to Dropdown")
      );
    }

    // Pad right rows to viewport height
    while (rightRows.length < viewportHeight) {
      rightRows.push(" ");
    }

    // Combine Left and Right columns into lines
    for (let i = 0; i < viewportHeight; i++) {
      const leftCol = padRight(leftRows[i] || "", leftWidth);
      const rightCol = padRight(rightRows[i] || "", rightWidth);
      const rowContent = ` ${leftCol} ${th.fg("borderMuted", "│")} ${rightCol} `;
      lines.push(
        truncateToWidth(
          th.fg("borderMuted", "│") +
            rowContent +
            th.fg("borderMuted", "│"),
          width
        )
      );
    }

    // 4. Bottom Footer Line
    const footerHint = this.inSearchMode
      ? " [Enter] Toggle Add/Remove  [Esc] Exit Search "
      : " [Enter] Select/Toggle  [←] Back  [→] Open  [/] Search  [R] Refresh  [Esc] Close ";
    const botDashes = Math.max(
      0,
      width - visibleWidth(footerHint) - 4
    );
    lines.push(
      th.fg("borderMuted", "└─") +
        th.fg("dim", footerHint) +
        th.fg("borderMuted", "─".repeat(botDashes)) +
        th.fg("borderMuted", "┘")
    );
    lines.push("");

    return lines;
  }
}

// ------------------------------------------------------------------ Browser Opener

async function openLiteLLMBrowser(
  ctx: ExtensionCommandContext,
  pi: ExtensionAPI
): Promise<void> {
  const base = getLiteLLMBase();
  const apiKey = getLiteLLMKey();
  const savedModels = loadSavedModels();

  await ctx.ui.custom<void>((tui, theme, _kb, done) => {
    return new LiteLLMBrowserComponent(
      tui,
      theme,
      done,
      pi,
      savedModels,
      base,
      apiKey
    );
  });
}

// ------------------------------------------------------------------ Extension Entry

export default async function litellmExtension(
  pi: ExtensionAPI
): Promise<void> {
  const base = getLiteLLMBase();
  const apiKey = getLiteLLMKey();

  // Load and register models on startup
  const savedModels = loadSavedModels();
  if (savedModels.size > 0) {
    syncProvider(pi, savedModels, base, apiKey);
  }

  // Register /litellm slash command
  pi.registerCommand("litellm", {
    description: "Manage models from LiteLLM gateway (add, remove, list)",
    getArgumentCompletions: (prefix) => {
      const trimmed = prefix.trimStart();
      const parts = trimmed.split(/\s+/);

      if (parts.length <= 1) {
        const subcmds = ["add", "remove", "list"];
        const matched = subcmds.filter((s) => s.startsWith(parts[0]));
        return matched.length > 0
          ? matched.map((s) => ({ value: s, label: s }))
          : null;
      }

      if (parts[0] === "remove") {
        const query = parts.slice(1).join(" ");
        const currentSaved = loadSavedModels();
        const ids = Array.from(currentSaved.keys()).filter((id) =>
          id.toLowerCase().includes(query.toLowerCase())
        );
        return ids.length > 0
          ? ids.map((id) => ({ value: `remove ${id}`, label: id }))
          : null;
      }

      return null;
    },
    handler: async (args, ctx) => {
      const currentSaved = loadSavedModels();
      const parts = args.trim().split(/\s+/).filter(Boolean);
      const subcmd = (parts[0] || "").toLowerCase();
      const modelArg = parts.slice(1).join(" ");

      if (subcmd === "add") {
        if (modelArg) {
          // Add specific model by ID if specified
          if (currentSaved.has(modelArg)) {
            ctx.ui.notify(
              `Model "${modelArg}" is already in the LiteLLM model dropdown.`,
              "info"
            );
            return;
          }
          // Fetch info to populate details
          ctx.ui.notify(`Looking up "${modelArg}" in LiteLLM catalog...`, "info");
          try {
            const catalog = await fetchCatalog(base, apiKey);
            const found = catalog.find(
              (m) =>
                (m.model_name || m.id || m.model_info?.id) === modelArg
            );
            if (found) {
              const saved = buildSavedModel(found);
              currentSaved.set(saved.id, saved);
              saveSavedModels(currentSaved);
              syncProvider(pi, currentSaved, base, apiKey);
              ctx.ui.notify(
                `Added "${saved.id}" to LiteLLM model dropdown!`,
                "info"
              );
            } else {
              // Create generic entry if not found in catalog
              const fallback: SavedModel = {
                id: modelArg,
                name: modelArg,
                contextWindow: 128000,
                maxTokens: 8192,
                reasoning: false,
                input: ["text"],
                cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
                provider: "openai",
                description: "Custom added model",
                addedAt: new Date().toISOString(),
              };
              currentSaved.set(fallback.id, fallback);
              saveSavedModels(currentSaved);
              syncProvider(pi, currentSaved, base, apiKey);
              ctx.ui.notify(
                `Added "${fallback.id}" to LiteLLM model dropdown.`,
                "info"
              );
            }
          } catch (err: unknown) {
            ctx.ui.notify(
              `Failed to lookup model: ${err instanceof Error ? err.message : String(err)}`,
              "error"
            );
          }
          return;
        }

        // Open TUI Tree Browser
        await openLiteLLMBrowser(ctx, pi);
        return;
      }

      if (subcmd === "remove") {
        if (modelArg) {
          if (!currentSaved.has(modelArg)) {
            ctx.ui.notify(
              `Model "${modelArg}" is not in the LiteLLM model dropdown.`,
              "warning"
            );
            return;
          }
          currentSaved.delete(modelArg);
          saveSavedModels(currentSaved);
          syncProvider(pi, currentSaved, base, apiKey);
          ctx.ui.notify(
            `Removed "${modelArg}" from LiteLLM model dropdown.`,
            "info"
          );
          return;
        }

        // No model specified: show selector
        if (currentSaved.size === 0) {
          ctx.ui.notify("No LiteLLM models are currently added.", "info");
          return;
        }

        const choices = Array.from(currentSaved.keys());
        const selected = await ctx.ui.select(
          "Select LiteLLM model to remove",
          choices
        );
        if (selected && currentSaved.has(selected)) {
          currentSaved.delete(selected);
          saveSavedModels(currentSaved);
          syncProvider(pi, currentSaved, base, apiKey);
          ctx.ui.notify(
            `Removed "${selected}" from LiteLLM model dropdown.`,
            "info"
          );
        }
        return;
      }

      if (subcmd === "list") {
        if (currentSaved.size === 0) {
          ctx.ui.notify(
            "No LiteLLM models added. Use /litellm add to browse and add models.",
            "info"
          );
          return;
        }

        const listText = Array.from(currentSaved.values())
          .map(
            (m) =>
              `• ${m.id} (${formatTokens(m.contextWindow)} ctx, reasoning: ${m.reasoning ? "yes" : "no"})`
          )
          .join("\n");
        ctx.ui.notify(
          `Added LiteLLM Models (${currentSaved.size}):\n${listText}`,
          "info"
        );
        return;
      }

      // Default: interactive action selection
      const action = await ctx.ui.select("LiteLLM Gateway", [
        "Add models (Browse tree)",
        "Remove a model",
        "List added models",
      ]);

      if (action === "Add models (Browse tree)") {
        await openLiteLLMBrowser(ctx, pi);
      } else if (action === "Remove a model") {
        if (currentSaved.size === 0) {
          ctx.ui.notify("No LiteLLM models are currently added.", "info");
          return;
        }
        const selected = await ctx.ui.select(
          "Select LiteLLM model to remove",
          Array.from(currentSaved.keys())
        );
        if (selected && currentSaved.has(selected)) {
          currentSaved.delete(selected);
          saveSavedModels(currentSaved);
          syncProvider(pi, currentSaved, base, apiKey);
          ctx.ui.notify(
            `Removed "${selected}" from LiteLLM model dropdown.`,
            "info"
          );
        }
      } else if (action === "List added models") {
        if (currentSaved.size === 0) {
          ctx.ui.notify(
            "No LiteLLM models added. Use /litellm add to browse and add models.",
            "info"
          );
          return;
        }
        const listText = Array.from(currentSaved.values())
          .map((m) => `• ${m.id}`)
          .join("\n");
        ctx.ui.notify(
          `Added LiteLLM Models (${currentSaved.size}):\n${listText}`,
          "info"
        );
      }
    },
  });
}
