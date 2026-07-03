{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings;
  isProgramming = cfg.programming or false;
  isPython = cfg.python or false;
  isLatex = cfg.latex or false;

  # Build kaiwood.tauren from the Open VSX / Marketplace (not in nixpkgs)
  tauren = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "tauren";
      publisher = "kaiwood";
      version = "1.8.0";
      sha256 = "sha256-RAlJgPON/CxOMroaoJc95pjtGzPQ+yVGi2PyyBY5UG8=";
    };
    meta = {
      description = "Transparent AI coding assistant built on the Pi agent";
      license = lib.licenses.mit;
    };
  };

  # Build Remote Repositories extension (not in nixpkgs)
  remoteRepositories = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "remote-repositories";
      publisher = "ms-vscode";
      version = "0.43.2026060101";
      sha256 = "sha256-NP/NAAFdK1KZeXppxcQNjsug1tVNR4SmfbY5ltICC6M=";
    };
    meta = {
      description = "Browse, search, edit, and commit to remote Git repositories directly from VS Code";
      license = lib.licenses.mit;
    };
  };

  # Core extensions always installed
  coreExtensions = with pkgs.vscode-extensions; [
    # AI coding assistant (kaiwood.tauren — not in nixpkgs, built above)
    tauren
    # Remote Repositories (ms-vscode.remote-repositories — built above)
    remoteRepositories
    # Remote - SSH
    ms-vscode-remote.remote-ssh
    # GitHub Codespaces
    github.codespaces
    # REST client — always useful
    humao.rest-client
    # Markdown
    shd101wyy.markdown-preview-enhanced
    yzhang.markdown-all-in-one
    # Bracket / UI niceties
    usernamehw.errorlens
    pkief.material-icon-theme
  ];

  # Programming-specific extensions (Rust, Kotlin, Nix, Jinja, Jupyter)
  programmingExtensions = lib.optionals isProgramming (with pkgs.vscode-extensions; [
    # Nix
    jnoortheen.nix-ide
    # Rust
    rust-lang.rust-analyzer
    # Kotlin
    mathiasfrohlich.kotlin
    # Jinja templates
    wholroyd.jinja
    # Jupyter notebooks
    ms-toolsai.jupyter
    ms-toolsai.jupyter-renderers
    ms-toolsai.vscode-jupyter-cell-tags
    ms-toolsai.vscode-jupyter-slideshow
  ]);

  # Python extensions
  pythonExtensions = lib.optionals isPython (with pkgs.vscode-extensions; [
    ms-python.python
    ms-python.vscode-pylance
    ms-python.debugpy
    ms-python.black-formatter
    ms-python.isort
  ]);

  # LaTeX extensions
  latexExtensions = lib.optionals isLatex (with pkgs.vscode-extensions; [
    james-yu.latex-workshop
  ]);

  allExtensions = coreExtensions ++ programmingExtensions ++ pythonExtensions ++ latexExtensions;
in {
  config = lib.mkIf cfg.editors.enable {
    stylix.targets.vscode.enable = true;

    programs.vscode = {
      enable = true;
      # FHS wrapper with language-server binaries available inside the chroot.
      # Packages are gated on the same feature flags as their extensions.
      package = pkgs.vscode.fhsWithPackages (p:
        lib.optionals isProgramming (with p; [
          cargo
          rustc
          rust-analyzer
        ])
        ++ lib.optionals isPython (with p; [
          python3
          python3Packages.ipykernel
          black
          isort
        ])
        ++ [p.nixd]);
      mutableExtensionsDir = false;

      profiles.default = {
        extensions = allExtensions;

        userSettings = {
          # ── Appearance & editor UX ────────────────────────────────────────────
          "editor.bracketPairColorization.enabled" = true;
          "editor.guides.bracketPairs" = "active";
          "editor.renderWhitespace" = "boundary";
          "editor.smoothScrolling" = true;
          "editor.cursorBlinking" = "smooth";
          "editor.cursorSmoothCaretAnimation" = "on";
          "editor.minimap.enabled" = false;
          "editor.lineNumbers" = "relative";
          "editor.wordWrap" = "off";
          "editor.formatOnSave" = true;
          "editor.inlineSuggest.enabled" = true;

          # ── Updates & Auto-updates ────────────────────────────────────────────
          "extensions.autoUpdate" = false;
          "extensions.autoCheckUpdates" = false;
          "update.mode" = "none";

          # ── Workbench ─────────────────────────────────────────────────────────
          "workbench.iconTheme" = "material-icon-theme";
          "workbench.tree.indent" = 16;
          "workbench.editor.enablePreview" = false;
          "workbench.startupEditor" = "none";

          # ── Telemetry — fully disabled ────────────────────────────────────────
          "telemetry.telemetryLevel" = "off";
          "telemetry.enableCrashReporter" = false;
          "telemetry.enableTelemetry" = false;
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

          # ── Rust Analyzer ─────────────────────────────────────────────────────
          "rust-analyzer.checkOnSave" = true;

          # ── LaTeX Workshop ────────────────────────────────────────────────────
          "latex-workshop.view.pdf.viewer" = "tab";
          "latex-workshop.latex.autoBuild.run" = "onSave";
          "latex-workshop.showContextMenu" = true;
          "latex-workshop.intellisense.package.enabled" = true;

          # ── REST Client ───────────────────────────────────────────────────────
          "rest-client.enableTelemetry" = false;

          # ── Window ────────────────────────────────────────────────────────────
          "window.titleBarStyle" = "custom";
          "window.zoomLevel" = 0;
        };
      };
    };
  };
}
