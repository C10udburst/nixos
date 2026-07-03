{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.homeSettings.ulauncher;

  # Override ulauncher to propagate Python dependencies required by the extensions
  ulauncherPkg = pkgs.ulauncher.overrideAttrs (oldAttrs: {
    propagatedBuildInputs =
      (oldAttrs.propagatedBuildInputs or [])
      ++ (with pkgs.python3Packages; [
        requests
        websocket-client
        pyclip
        pyperclip
      ]);
  });

  defaultSettings = pkgs.writeText "ulauncher-settings.json" (builtins.toJSON {
    "clear-on-show" = true;
    "hotkey-show-app" = "<Ctrl>space";
    "theme-name" = "dark";
  });
in {
  options.homeSettings.ulauncher = {
    enable = lib.mkEnableOption "Enable Ulauncher configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      ulauncherPkg
      pkgs.bitwarden-cli
      pkgs.copyq
    ];

    # Install extensions declaratively by symlinking their source from flake inputs
    xdg.dataFile = {
      "ulauncher/extensions/com.github.pucodev.ulauncher-homepage".source = inputs.ulauncher-homepage;
      "ulauncher/extensions/com.github.ulauncher.ulauncher-emoji".source = inputs.ulauncher-emoji;
      "ulauncher/extensions/com.github.friday.ulauncher-clipboard".source = inputs.ulauncher-clipboard;
      "ulauncher/extensions/com.github.iboyperson.ulauncher-system".source = inputs.ulauncher-system;
      "ulauncher/extensions/com.github.kbialek.ulauncher-bitwarden".source = inputs.ulauncher-bitwarden;
      "ulauncher/extensions/com.github.qcasey.ulauncher-homeassistant".source = inputs.ulauncher-homeassistant;
      "ulauncher/extensions/com.github.zensoup.ulauncher-unicode".source = inputs.ulauncher-unicode;
      "ulauncher/extensions/com.github.khurrambhutto.ulauncher-google-ai-mode".source = inputs.ulauncher-google-ai-mode;
      "ulauncher/extensions/com.github.daste745.ulauncher-nix".source = inputs.ulauncher-nix;
    };

    # Start Ulauncher automatically as a systemd user service for graphical sessions
    systemd.user.services.ulauncher = {
      Unit = {
        Description = "Ulauncher application launcher";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${ulauncherPkg}/bin/ulauncher --hide-window";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };

    # Configure custom shortcut in KDE Plasma using plasma-manager
    programs.plasma = lib.mkIf config.homeSettings.plasma.enable {
      hotkeys.commands."ulauncher-toggle" = {
        name = "Toggle Ulauncher";
        command = "ulauncher-toggle";
        key = "Ctrl+Space";
      };
    };

    # Seed default writable settings if they do not exist
    home.activation.setupUlauncher = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -f "$HOME/.config/ulauncher/settings.json" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.config/ulauncher"
        $DRY_RUN_CMD cp ${defaultSettings} "$HOME/.config/ulauncher/settings.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.config/ulauncher/settings.json"
      fi
    '';
  };
}
