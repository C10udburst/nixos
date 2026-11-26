# VS Code user settings shared by both front-ends: the desktop profile
# (./default.nix, written into the `default` profile by Home Manager) and the
# browser server (./web.nix, installed as `User/settings.json` of its own
# user-data directory on first start). Web-only entries are harmless in the
# browser, so the two stay on one source of truth.
{
  "files.associations" = {
    "*.luau" = "lua";
  };

  # ── Security & Trust ──────────────────────────────────────────────────
  "security.workspace.trust.enabled" = false;

  # ── Appearance & editor UX ────────────────────────────────────────────
  "editor.bracketPairColorization.enabled" = true;
  "editor.guides.bracketPairs" = "active";
  "editor.renderWhitespace" = "boundary";
  "editor.smoothScrolling" = true;
  "editor.cursorBlinking" = "smooth";
  "editor.cursorSmoothCaretAnimation" = "on";
  "editor.minimap.enabled" = false;
  "editor.lineNumbers" = "on";
  "editor.wordWrap" = "off";
  "editor.formatOnSave" = true;
  "editor.inlineSuggest.enabled" = true;
  "editor.mouseWheelZoom" = true;

  # ── Updates & Auto-updates ────────────────────────────────────────────
  "extensions.autoUpdate" = false;
  "extensions.autoCheckUpdates" = false;
  "update.mode" = "none";

  # ── Workbench ─────────────────────────────────────────────────────────
  "workbench.iconTheme" = "material-icon-theme";
  "workbench.tree.indent" = 16;
  "workbench.editor.enablePreview" = false;
  "workbench.startupEditor" = "none";

  # Keep the auxiliary bar (Copilot / chat view) closed on startup
  # default is "visibleInWorkspace", which autoopens chat in every window
  "workbench.secondarySideBar.defaultVisibility" = "hidden";

  # ── Telemetry — fully disabled ────────────────────────────────────────
  "telemetry.telemetryLevel" = "off";
  "redhat.telemetry.enabled" = false;
  "ms-python.python.experiments.enabled" = false;
  "julia.enableTelemetry" = false;

  # ── Sync — disabled ───────────────────────────────────────────────────
  "settingsSync.keybindingsPerPlatform" = false;
  "sync.gist" = "";

  # ── Files ─────────────────────────────────────────────────────────────
  "files.autoSave" = "onFocusChange";
  "files.trimTrailingWhitespace" = true;
  "files.insertFinalNewline" = true;

  # ── Terminal ──────────────────────────────────────────────────────────
  "terminal.integrated.smoothScrolling" = true;

  # ── Git ───────────────────────────────────────────────────────────────
  "git.autofetch" = true;
  "git.confirmSync" = false;

  # ── Nix IDE ───────────────────────────────────────────────────────────
  "nix.enableLanguageServer" = true;
  "nix.serverPath" = "nixd";
  "nix.formatterPath" = "alejandra";

  # ── Rust Analyzer ─────────────────────────────────────────────────────
  "rust-analyzer.checkOnSave" = true;

  # ── LaTeX Workshop ────────────────────────────────────────────────────
  "latex-workshop.view.pdf.viewer" = "tab";
  "latex-workshop.latex.autoBuild.run" = "onSave";
  "latex-workshop.showContextMenu" = true;
  "latex-workshop.intellisense.package.enabled" = true;

  # ── Typst (Tinymist) ──────────────────────────────────────────────────
  "[typst]" = {
    "editor.formatOnSave" = true;
  };
  "tinymist.formatterMode" = "typstyle";

  # ── REST Client ───────────────────────────────────────────────────────
  "rest-client.enableTelemetry" = false;

  # ── Window ────────────────────────────────────────────────────────────
  "window.titleBarStyle" = "custom";
  "window.zoomLevel" = 0;

  # ── Pi Agent Studio (LLM) ─────────────────────────────────────────────
  "pi-agent-studio.ui" = "webview";

  # --- Kotlin Server (JetBrains) ─────────────────────────────────────────
  "intellij.region" = "europe";
  "intellij.dataSharing" = "none";
}
