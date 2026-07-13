{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.arduino;

  # Map board names to arduino-cli core identifiers
  boardCoreMap = {
    arduino = "arduino:avr";
    esp32 = "esp32:esp32";
    esp8266 = "esp8266:esp8266";
    digispark = "digistump:avr";
    teensy = "teensy:avr";
    stm32 = "STMicroelectronics:stm32";
    rp2040 = "rp2040:rp2040";
  };

  selectedCores = lib.filter (b: builtins.hasAttr b boardCoreMap) cfg.boards;

  # Pretty-print board list for the helper script
  coresList = lib.concatStringsSep " " (map (b: boardCoreMap.${b}) selectedCores);
in {
  options.systemSettings.arduino = {
    enable = lib.mkEnableOption "Arduino / embedded development environment";

    boards = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["arduino"];
      example = ["arduino" "esp32" "digispark"];
      description = ''
        Board families to support. Recognised values:
        arduino, esp32, esp8266, digispark, teensy, stm32, rp2040.
        Controls which arduino-cli cores are noted in the install helper script.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      arduino-cli
      arduino-ide
      platformio
      platformio-core
      avrdude
    ];

    # udev rules so non-root users can access USB-serial adapters
    services.udev.packages = with pkgs; [
      arduino-ide
      platformio-core
    ];

    # Members of plugdev / dialout can talk to serial ports / USB devices
    users.groups.plugdev = {};
    users.groups.dialout = {};

    # Add every configured user to the needed groups
    users.users = lib.genAttrs config.systemSettings.users (
      _: {
        extraGroups = ["plugdev" "dialout" "uucp"];
      }
    );

    # Convenience script: arduino-setup
    # Prints the arduino-cli commands needed to install the selected board cores.
    environment.shellAliases.arduino-setup = let
      script = pkgs.writeShellScriptBin "arduino-setup" ''
        set -euo pipefail
        echo "==> Adding board manager URLs for non-standard boards…"
        ${lib.optionalString (builtins.elem "esp32" cfg.boards) ''
          arduino-cli config add board_manager.additional_urls \
            https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
        ''}
        ${lib.optionalString (builtins.elem "esp8266" cfg.boards) ''
          arduino-cli config add board_manager.additional_urls \
            https://arduino.esp8266.com/stable/package_esp8266com_index.json
        ''}
        ${lib.optionalString (builtins.elem "digispark" cfg.boards) ''
          arduino-cli config add board_manager.additional_urls \
            https://raw.githubusercontent.com/digistump/DigistumpArduino/master/package_digistump_index.json
        ''}
        echo "==> Installing cores: ${coresList}"
        ${lib.concatMapStringsSep "\n" (core: "arduino-cli core install ${core}") (map (b: boardCoreMap.${b}) selectedCores)}
        echo "==> Done! Run 'arduino-cli board list' to verify detected boards."
      '';
    in "${script}/bin/arduino-setup";
  };
}
