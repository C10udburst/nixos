{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.desktop.plasma;
in {
  options.features.gui.desktop.plasma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.desktop.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        plasma-manager = {
          url = "github:nix-community/plasma-manager";
          inputs.nixpkgs.follows = "nixpkgs";
          inputs.home-manager.follows = "home-manager";
        };
      };
    }
    (lib.mkIf cfg.enable {
      services.xserver.enable = true;
      services.desktopManager.plasma6.enable = true;
      programs.xwayland.enable = true;
      programs.kdeconnect.enable = true;

      services.libinput.mouse.accelProfile = "flat";
      services.libinput.mouse.accelSpeed = "0";

      home-manager.users.cloudburst = {
        programs.plasma = {
          enable = true;
          workspace = {
            iconTheme = "breeze-dark";
            colorScheme = "Stylix";
          };
          configFile."kdeglobals" = {
            General.ColorScheme = "Stylix";
          };
          krunner = {
            shortcuts.launch = "Meta+Space";
          };
          shortcuts = {
            "services/qalculate-qt.desktop" = {
              _launch = "Launch (1)";
            };
          };
        };
      };
    })
  ];
}
