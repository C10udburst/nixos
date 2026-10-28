{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.zed;
  editorsEnabled = config.features.gui.apps.editors.enable;

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
  isOmp = config.features.gui.apps.tools.llm.omp.enable or false;

  # Zed extensions (slugs from https://github.com/zed-industries/extensions).
  # Rust, Go, Python, JSON, YAML and Markdown are bundled with Zed itself,
  # so they need no extension; only genuinely missing ones are listed.

  # Core extensions always installed
  coreExtensions = [
    # Nix (nixd / nil integration)
    "nix"
    "toml"
    "make"
    "dockerfile"
    # Gitignore templates
    "gitignore-templates"
    # GitHub Actions
    "github-actions"
    # HTTP / REST files — always useful
    "http"
    # Markdown preview & LSP
    "markdown-oxide"
    # Hex Editor
    "hexpeek"
  ];

  programmingExtensions =
    lib.optionals isProgramming [
      "jinja2"
      "glsl"
      "luau"
    ]
    ++ lib.optionals isKotlin [
      # Kotlin (rust-analyzer, gopls, pyright ship with Zed's built-in languages)
      "kotlin"
    ];

  allExtensions =
    coreExtensions
    ++ programmingExtensions
    ++ lib.optionals isLatex ["latex"]
    ++ lib.optionals isTypst ["typst"]
    ++ lib.optionals isArduino [
      "arduino"
      "platformio"
    ]
    ++ lib.optionals isThreed ["gcode"];
  # NOTE: no Zed equivalent exists for Pi Agent Studio; Zed's agent panel is
  # configured via userSettings instead, so `tools.llm` adds no extension.
in {
  options.features.gui.apps.editors.zed = lib.mkOption {
    type = lib.types.bool;
    default = editorsEnabled && true;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst = lib.mkMerge [
      (lib.mkIf (config.stylix.enable or false) {
        stylix.targets.zed.enable = true;
        # tinted-zed renders {{scheme-variant}} into the theme's "appearance"
        # field; stylix's palette carries no variant, so it emits
        # "unspecified" — invalid for Zed, which silently drops the theme and
        # rewrites settings.json to its fallback. Pin it to the palette polarity.
        stylix.targets.zed.colors.override = {
          scheme-variant = config.stylix.polarity or "dark";
        };
      })
      {
        # nixpkgs ships the binary as `zeditor` (the `zed` name is taken by
        # zzip's frontend); expose the conventional `zed` on PATH.
        home.packages = [
          (pkgs.writeShellScriptBin "zed" ''
            exec ${pkgs.zed-editor}/bin/zeditor "$@"
          '')
        ];

        programs.zed-editor = {
          enable = true;
          extensions = allExtensions;

          extraPackages =
            lib.optionals isProgramming (
              lib.optionals isRust [
                pkgs.cargo
                pkgs.rustc
                pkgs.rust-analyzer
              ]
              ++ lib.optionals isGo [
                pkgs.go
                pkgs.gopls
              ]
            )
            ++ lib.optionals isPython [
              pkgs.python3
            ]
            ++ lib.optionals isTypst [
              pkgs.typst
              pkgs.typstyle
            ]
            ++ [
              pkgs.nixd
              pkgs.nixfmt
            ];

          userSettings =
            {
              # ── Appearance & editor UX ──────────────────────────────────────────────
              "show_line_numbers" = true;
              "relative_line_numbers" = false;
              "minimap" = {
                "show" = "always";
                "current_line_highlight" = "all";
              };
              "document_folding_ranges" = "on";
              "document_symbols" = "on";
              "soft_wrap" = "none";
              "indent_guides" = {
                "colorize_brackets" = true;
              };
              "mouse_wheel_zoom" = true;
              "format_on_save" = "on";

              # ── Startup / sessions ──────────────────────────────────────────────────
              "session" = {
                "trust_all_worktrees" = true;
              };

              # ── Files ───────────────────────────────────────────────────────────────
              "autosave" = "on_focus_change";

              # ── Telemetry — fully disabled ──────────────────────────────────────────
              "telemetry" = {
                "diagnostics" = false;
                "metrics" = false;
              };
            }
            // lib.optionalAttrs isRust {
              # ── Rust Analyzer ───────────────────────────────────────────────────────
              "lsp" = {
                "rust-analyzer" = {
                  "settings" = {
                    "check" = {
                      "onSave" = true;
                    };
                  };
                };
              };
            }
            // lib.optionalAttrs isOmp {
              # ── External ACP agents ─────────────────────────────────────────────────
              "agent_servers" = {
                "omp" = {
                  "type" = "custom";
                  "command" = "omp";
                  "args" = ["acp"];
                };
              };
            };
        };

        xdg.mimeApps.associations.added = {
          "inode/directory" = ["dev.zed.Zed.desktop"];
        };
      }
    ];
  };
}
