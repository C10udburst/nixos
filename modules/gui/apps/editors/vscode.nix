{
  config,
  lib,
  pkgs,
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
  isThreed = isDev && (config.features.gui.dev.threed.enable or false);

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

  config = lib.mkIf (editorsEnabled && cfg) {
    home-manager.users.cloudburst = {
      programs.vscode = {
        enable = true;
        extensions = coreExtensions;
      };
    };
  };
}
