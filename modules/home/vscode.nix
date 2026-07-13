{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.homeSettings;
  isProgramming = cfg.programming.enable or false;
  isPython = cfg.python or false;
  isLatex = cfg.latex or false;
  isTypst = cfg.typst or false;
  isArduino = (cfg.arduino or {}).enable or false;
  isThreed = cfg.threed or false;
  isLlm = cfg.llm.enable or false;

  exts = pkgs.vscode-marketplace;

  # Core extensions always installed
  coreExtensions = with exts; [
    # Remote Repositories
    ms-vscode.remote-repositories
    # Remote - SSH
    ms-vscode-remote.remote-ssh
    # GitHub Codespaces
    github.codespaces
    # GitHub Pull Requests
    github.vscode-pull-request-github
    # REST client — always useful
    humao.rest-client
    # Markdown
    shd101wyy.markdown-preview-enhanced
    yzhang.markdown-all-in-one
    # Hex Editor
    ms-vscode.hexeditor
    # Shell Formatter
    foxundermoon.shell-format
    # JSON Formatter
    zainchen.json
    # Bracket / UI niceties
    usernamehw.errorlens
    pkief.material-icon-theme
    kamikillerto.vscode-colorize
    # Nix
    jnoortheen.nix-ide
  ];

  programmingExtensions = lib.optionals isProgramming (with exts;
    [
      wholroyd.jinja
      jock.svg
    ]
    ++ lib.optionals (cfg.programming.rust or false) [
      rust-lang.rust-analyzer
    ]
    ++ lib.optionals (cfg.programming.go or false) [
      golang.go
    ]
    ++ lib.optionals (cfg.programming.kotlin or false) [
      mathiasfrohlich.kotlin
    ]);

  # Python extensions
  pythonExtensions = lib.optionals isPython (with exts; [
    ms-python.python
    ms-python.vscode-pylance
    ms-python.debugpy
    ms-python.black-formatter
    ms-python.isort
    ms-toolsai.jupyter
    ms-toolsai.jupyter-renderers
    ms-toolsai.vscode-jupyter-cell-tags
    ms-toolsai.vscode-jupyter-slideshow
  ]);

  allExtensions =
    coreExtensions
    ++ programmingExtensions
    ++ pythonExtensions
    ++ lib.optionals isLatex [exts.james-yu.latex-workshop]
    ++ lib.optionals isTypst [exts.myriad-dreamin.tinymist]
    ++ lib.optionals isArduino [exts.platformio.platformio-ide exts.ms-vscode.cpptools]
    ++ lib.optionals isThreed [exts.appliedengdesign.vscode-gcode-syntax]
    ++ lib.optionals isLlm [exts.kaiwood.tauren];
  fhsVscode = pkgs.vscode.fhsWithPackages (p:
    lib.optionals isProgramming (with p;
      [
        cargo
        rustc
        rust-analyzer
      ]
      ++ lib.optionals (cfg.programming.go or false) [
        go
        gopls
      ])
    ++ lib.optionals isPython (with p; [
      python3
      python3Packages.ipykernel
      black
      isort
    ])
    ++ lib.optionals isTypst (with p; [
      typst
      typstyle
    ])
    ++ [p.nixd]);

  ephemeralVscode = pkgs.symlinkJoin {
    name = "code";
    paths = [fhsVscode];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm $out/bin/code
      makeWrapper ${fhsVscode}/bin/code $out/bin/code \
        --run '
          REAL_CODE_DIR="''${HOME}/.config/Code"
          TEMP_DIR="/tmp/vscode-profile-''${USER}"

          # Ensure real directory structure exists
          mkdir -p "''${REAL_CODE_DIR}/User"

          # Recreate temp layout
          rm -rf "''${TEMP_DIR}"
          mkdir -p "''${TEMP_DIR}/User"

          # Link root items except User
          for item in "''${REAL_CODE_DIR}"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            if [ "$name" != "User" ]; then
              ln -sf "$item" "''${TEMP_DIR}/$name"
            fi
          done

          # Link User items except settings and keybindings
          for item in "''${REAL_CODE_DIR}/User"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            if [ "$name" != "settings.json" ] && [ "$name" != "keybindings.json" ]; then
              ln -sf "$item" "''${TEMP_DIR}/User/$name"
            fi
          done

          # Copy settings and keybindings if they exist
          if [ -f "''${REAL_CODE_DIR}/User/settings.json" ]; then
            cp -Lf "''${REAL_CODE_DIR}/User/settings.json" "''${TEMP_DIR}/User/settings.json"
            chmod +w "''${TEMP_DIR}/User/settings.json"
          fi
          if [ -f "''${REAL_CODE_DIR}/User/keybindings.json" ]; then
            cp -Lf "''${REAL_CODE_DIR}/User/keybindings.json" "''${TEMP_DIR}/User/keybindings.json"
            chmod +w "''${TEMP_DIR}/User/keybindings.json"
          fi
        ' \
        --add-flags '--user-data-dir /tmp/vscode-profile-''${USER}'
    '';
  };
in {
  config = {
    stylix.targets.vscode.enable = true;

    programs.vscode = {
      enable = true;
      package = ephemeralVscode;
      mutableExtensionsDir = false;

      profiles.default = {
        extensions = allExtensions;

        userSettings = {
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
          "editor.lineNumbers" = "relative";
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

          # ── Telemetry — fully disabled ────────────────────────────────────────
          "telemetry.telemetryLevel" = "off";
          #"telemetry.enableCrashReporter" = false;
          #"telemetry.enableTelemetry" = false;
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

          # ── Colorize ──────────────────────────────────────────────────────────
          "colorize.include" = ["**/*"];
          "colorize.decoration_type" = "background";
        };
      };
    };
  };
}
