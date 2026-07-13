{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.arduino;

  # Map board names to core identifiers and board manager URLs
  boardsConfig = {
    arduino = {
      core = "arduino:avr";
      url = null;
    };
    esp32 = {
      core = "esp32:esp32";
      url = "https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json";
    };
    esp8266 = {
      core = "esp8266:esp8266";
      url = "https://arduino.esp8266.com/stable/package_esp8266com_index.json";
    };
    digispark = {
      core = "digistump:avr";
      url = "https://raw.githubusercontent.com/digistump/arduino-boards-index/master/package_digistump_index.json";
    };
    teensy = {
      core = "teensy:avr";
      url = "https://www.pjrc.com/teensy/package_teensy_index.json";
    };
    stm32 = {
      core = "STMicroelectronics:stm32";
      url = "https://github.com/stm32duino/BoardManagerFiles/raw/main/package_stmicroelectronics_index.json";
    };
    rp2040 = {
      core = "rp2040:rp2040";
      url = "https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json";
    };
  };

  selectedBoards = lib.filter (b: builtins.hasAttr b boardsConfig) cfg.boards;
  selectedCores = map (b: boardsConfig.${b}.core) selectedBoards;
  selectedUrls = lib.filter (url: url != null) (map (b: boardsConfig.${b}.url or null) selectedBoards);

  # Pretty-print board list for the helper script
  coresList = lib.concatStringsSep " " selectedCores;
  urlsList = lib.concatStringsSep " " selectedUrls;

  arduinoSetupScript = pkgs.writeShellScriptBin "arduino-setup" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [pkgs.arduino-cli pkgs.jq]}:$PATH"

    STATE_FILE="$HOME/.arduino15/.nixos-boards-installed"
    CURRENT_BOARDS="${coresList}"

    FORCE=false
    for arg in "$@"; do
      if [ "$arg" = "--force" ] || [ "$arg" = "-f" ]; then
        FORCE=true
      fi
    done

    if [ "$FORCE" = false ] && [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$CURRENT_BOARDS" ]; then
      echo "Selected Arduino cores ($CURRENT_BOARDS) are already installed. Use --force to re-sync."
      exit 0
    fi

    echo "==> Setting up Arduino CLI and installing cores: $CURRENT_BOARDS"

    # Initialize configuration if not exists
    if [ ! -f "$HOME/.arduino15/arduino-cli.yaml" ]; then
      arduino-cli config init || true
    fi

    # Reset/set the additional URLs to exactly what is configured
    urls=(${urlsList})
    if [ ''${#urls[@]} -gt 0 ]; then
      echo "==> Configuring additional board manager URLs…"
      arduino-cli config set board_manager.additional_urls "''${urls[@]}"
    else
      echo "==> Clearing additional board manager URLs…"
      # If no custom URLs, set to empty
      arduino-cli config set board_manager.additional_urls "" || true
    fi

    echo "==> Updating core indexes..."
    arduino-cli core update-index

    # Install the selected cores
    echo "==> Installing selected cores..."
    ${lib.concatMapStringsSep "\n" (core: ''
        echo "Installing ${core}..."
        arduino-cli core install "${core}"
      '')
      selectedCores}

    # Declarative removal: Uninstall any installed cores that are not in the selected list
    echo "==> Pruning unselected cores..."
    declare -A selected_cores
    ${lib.concatMapStringsSep "\n" (core: ''selected_cores["${core}"]=1'') selectedCores}

    if installed_json=$(arduino-cli core list --format json 2>/dev/null); then
      echo "$installed_json" | jq -r '.platforms[].id' | while read -r installed_core; do
        if [ -n "$installed_core" ] && [ -z "''${selected_cores[$installed_core]+x}" ]; then
          echo "==> Uninstalling unselected core: $installed_core"
          arduino-cli core uninstall "$installed_core"
        fi
      done
    fi

    echo "==> Done! Writing state file."
    echo "$CURRENT_BOARDS" > "$STATE_FILE"
  '';
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
      arduinoSetupScript
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

    # Automatically run the board installation service
    systemd.user.services.arduino-setup = {
      description = "Automatically install selected Arduino cores";
      wantedBy = ["default.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${arduinoSetupScript}/bin/arduino-setup";
        RemainAfterExit = true;
      };
    };
  };
}
