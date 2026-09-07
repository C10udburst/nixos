{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.editors.vscode;
  editorsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable;

  isDev = config.features.gui.dev.enable or false;
  isProgramming = isDev && (config.features.gui.dev.programming.enable or false);
  isRust = isProgramming && (config.features.gui.dev.programming.rust or false);
  isGo = isProgramming && (config.features.gui.dev.programming.go or false);
  isKotlin = isProgramming && (config.features.gui.dev.programming.kotlin or false);
  isPython = isDev && (config.features.gui.dev.python.enable or false);
  isLatex = isDev && (config.features.gui.dev.documents.latex or false);
  isTypst = isDev && (config.features.gui.dev.documents.typst or false);
  isArduino = isDev && (config.features.gui.dev.arduino.enable or false);
  isThreed = config.features.gui.apps.threed.enable or false;
  isLlm = config.features.gui.apps.tools.llm.enable or false;

  exts = pkgs.vscode-marketplace;

  # Core extensions always installed
  coreExtensions = with exts; [
    # Add Gitignore command
    codezombiech.gitignore

    # Remote Repositories
    ms-vscode.remote-repositories
    # Remote - SSH
    ms-vscode-remote.remote-ssh
    # GitHub Codespaces
    github.codespaces
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

  programmingExtensions = lib.optionals isProgramming (
    with exts;
      [
        wholroyd.jinja
        jock.svg
        slevesque.shader
      ]
      ++ lib.optionals isRust [
        rust-lang.rust-analyzer
      ]
      ++ lib.optionals isGo [
        golang.go
      ]
      ++ lib.optionals isKotlin [
        mathiasfrohlich.kotlin
      ]
  );

  # Python extensions
  pythonExtensions = lib.optionals isPython (
    with exts; [
      ms-python.python
      ms-python.vscode-pylance
      ms-python.debugpy
      ms-python.black-formatter
      ms-python.isort
      ms-toolsai.jupyter
      ms-toolsai.jupyter-renderers
      ms-toolsai.vscode-jupyter-cell-tags
      ms-toolsai.vscode-jupyter-slideshow
    ]
  );

  allExtensions =
    coreExtensions
    ++ programmingExtensions
    ++ pythonExtensions
    ++ lib.optionals isLatex [exts.james-yu.latex-workshop]
    ++ lib.optionals isTypst [exts.myriad-dreamin.tinymist]
    ++ lib.optionals isArduino [
      exts.platformio.platformio-ide
      pkgs.vscode-extensions.ms-vscode.cpptools
    ]
    ++ lib.optionals isThreed [exts.appliedengdesign.vscode-gcode-syntax]
    ++ lib.optionals isLlm [exts.kaiwood.tauren];

  fhsVscode = pkgs.vscode.fhsWithPackages (
    p:
      lib.optionals isProgramming (
        with p;
          lib.optionals isRust [
            cargo
            rustc
            rust-analyzer
          ]
          ++ lib.optionals isGo [
            go
            gopls
          ]
      )
      ++ lib.optionals isPython (
        with p; [
          python3
          python3Packages.ipykernel
          black
          isort
        ]
      )
      ++ lib.optionals isTypst (
        with p; [
          typst
          typstyle
        ]
      )
      ++ [
        p.nixd
        p.nixfmt
      ]
  );

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
        --add-flags '--user-data-dir /tmp/vscode-profile-''${USER}' \
        --add-flags '--enable-features=UseOzonePlatform --ozone-platform=wayland'
    '';
  };
in {
  options.features.gui.apps.editors.vscode = lib.mkOption {
    type = lib.types.bool;
    default = editorsEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        nix-vscode-extensions = {
          url = "github:nix-community/nix-vscode-extensions";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg {
      nixpkgs.overlays = [
        (inputs.nix-vscode-extensions.overlays.default or (_: _: {}))
      ];

      home-manager.users.cloudburst = {
        stylix.targets.vscode.enable = true;

        programs.vscode = {
          enable = true;
          package = ephemeralVscode;
          mutableExtensionsDir = false;

          profiles.default = {
            extensions = allExtensions;

            userSettings = {
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

        xdg.mimeApps = {
          defaultApplications = {
            "text/javascript" = ["code.desktop"];
            "application/javascript" = ["code.desktop"];
            "text/x-python" = ["code.desktop"];
            "text/x-rust" = ["code.desktop"];
            "text/x-c" = ["code.desktop"];
            "text/x-c++" = ["code.desktop"];
            "text/x-go" = ["code.desktop"];
            "text/x-java" = ["code.desktop"];
            "text/plain" = ["code.desktop"];
            "text/x-shellscript" = ["code.desktop"];
            "application/json" = ["code.desktop"];
            "text/markdown" = ["code.desktop"];
            "text/x-nix" = ["code.desktop"];
            "text/x-yaml" = ["code.desktop"];
            "text/x-toml" = ["code.desktop"];
            "text/x-ini" = ["code.desktop"];
            "text/x-xml" = ["code.desktop"];
            "text/x-sql" = ["code.desktop"];
            "text/x-php" = ["code.desktop"];
            "text/x-perl" = ["code.desktop"];
            "text/x-ruby" = ["code.desktop"];
            "text/x-lua" = ["code.desktop"];
            "text/x-haskell" = ["code.desktop"];
            "text/x-scala" = ["code.desktop"];
            "text/x-kotlin" = ["code.desktop"];
            "text/x-vb" = ["code.desktop"];
          };
          associations.added = {
            "inode/directory" = ["code.desktop"];
          };
        };
      };
    })
  ];
}
