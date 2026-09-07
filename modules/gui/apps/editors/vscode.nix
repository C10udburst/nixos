{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.editors.vscode;
  editorsEnabled = config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.editors.enable;

  isDev = config.features.gui.dev.enable or false;
  isProgramming = isDev && (config.features.gui.dev.programming.enable or false);
  isPython = isDev && (config.features.gui.dev.python.enable or false);
  isLatex = isDev && (config.features.gui.dev.documents.latex or false);
  isTypst = isDev && (config.features.gui.dev.documents.typst or false);
  isArduino = isDev && (config.features.gui.dev.arduino.enable or false);
  isThreed = config.features.gui.apps.threed.enable or false;

  exts = pkgs.vscode-marketplace or {};

  coreExtensions = lib.optionals (pkgs ? vscode-marketplace) (
    with exts;
      [
        codezombiech.gitignore
        ms-vscode.remote-repositories
        ms-vscode-remote.remote-ssh
        github.codespaces
        humao.rest-client
        shd101wyy.markdown-preview-enhanced
        yzhang.markdown-all-in-one
        ms-vscode.hexeditor
        foxundermoon.shell-format
        zainchen.json
        usernamehw.errorlens
        pkief.material-icon-theme
        kamikillerto.vscode-colorize
        jnoortheen.nix-ide
      ]
      ++ lib.optionals isProgramming [
        wholroyd.jinja
        jock.svg
        slevesque.shader
      ]
      ++ lib.optionals (isProgramming && (config.features.gui.dev.programming.rust.enable or false)) [
        rust-lang.rust-analyzer
      ]
      ++ lib.optionals (isProgramming && (config.features.gui.dev.programming.go or false)) [
        golang.go
      ]
      ++ lib.optionals isPython [
        ms-python.python
        charliermarsh.ruff
      ]
      ++ lib.optionals isLatex [
        james-yu.latex-workshop
      ]
      ++ lib.optionals isTypst [
        myriad-dreamin.tinymist
      ]
      ++ lib.optionals isArduino [
        platformio.platformio-ide
        pkgs.vscode-extensions.ms-vscode.cpptools
      ]
      ++ lib.optionals isThreed [
        appliedengdesign.vscode-gcode-syntax
      ]
      ++ lib.optionals (config.features.gui.apps.tools.llm.enable or false) [
        kaiwood.tauren
      ]
  );
in {
  options.features.gui.apps.editors.vscode = lib.mkOption {
    type = lib.types.bool;
    default = true;
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
    (lib.mkIf (editorsEnabled && cfg) {
      nixpkgs.overlays = [
        (inputs.nix-vscode-extensions.overlays.default or (_: _: {}))
      ];

      home-manager.users.cloudburst = {
        programs.vscode = {
          enable = true;
          extensions = coreExtensions;
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
