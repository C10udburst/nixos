{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.desktop.driftwm.handwriting;
  driftwmEnabled = config.features.gui.desktop.driftwm.enable;
  touchscreen = config.features.core.hardware.touchscreen or false;

  handwriting-input = inputs.handwriting-input.packages.${pkgs.stdenv.hostPlatform.system}.handwriting-input;

  # The app has no flags: its single positional argument is the path to this TOML
  # file, and any key left out falls back to the upstream default. English and
  # Polish; dark visuals are already the default (`theme = "auto"` resolves to
  # dark, matching the overlay keyboard aesthetic).
  configToml = (pkgs.formats.toml {}).generate "handwriting-input.toml" {
    langs = ["en" "pl"];
  };
in {
  options.features.gui.desktop.driftwm.handwriting = lib.mkOption {
    type = lib.types.bool;
    default = driftwmEnabled && touchscreen;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs.handwriting-input = {
        url = "github:C10udburst/handwriting-input";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    }
    (lib.mkIf cfg {
      # injection is native Wayland (zwp_input_method_v2, zwp_virtual_keyboard_v1,
      # zwlr_data_control_v1) so no ydotool/uinput daemon, group or udev rule is
      # needed; the compositor does the work
      environment.systemPackages = [handwriting-input];

      # placed where the app would look anyway, so a bare `handwriting-input`
      # start reads the same file. force = true because the app writes its own
      # defaults there when the file is missing, which would otherwise make
      # home-manager activation collide with it
      home-manager.users.cloudburst.xdg.configFile."handwriting-input/config.toml" = {
        source = configToml;
        force = true;
      };
    })
  ];
}
