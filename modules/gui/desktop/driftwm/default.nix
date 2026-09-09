{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.desktop.driftwm;
  isSlow = config.features.core.hardware.slow or false;
  isTouchscreen = config.features.core.hardware.touchscreen or false;
in {
  options.features.gui.desktop.driftwm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.desktop.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        driftwm = {
          url = "github:malbiruk/driftwm";
          inputs.nixpkgs.follows = "nixpkgs";
        };
        driftwm-desktop = {
          url = "github:C10udburst/driftwm-desktop";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      programs.kdeconnect.enable = lib.mkDefault (!isSlow);

      systemd.packages = [pkgs.driftwm];

      environment.systemPackages =
        [
          pkgs.driftwm
          pkgs.grim
          pkgs.slurp
          pkgs.wlroots
          pkgs.wlr-randr
          pkgs.wl-clipboard
          pkgs.playerctl
          pkgs.pamixer
          pkgs.xwayland-satellite
          pkgs.libsForQt5.qtsvg
          pkgs.kdePackages.qtsvg
          pkgs.libsForQt5.qt5ct
          pkgs.kdePackages.qt6ct
          pkgs.kdePackages.breeze
          pkgs.kdePackages.breeze.qt5
          pkgs.kdePackages.breeze-gtk
          pkgs.kdePackages.qqc2-breeze-style
        ]
        ++ lib.optionals (!isSlow) [
          pkgs.kdePackages.kdeconnect-kde
          pkgs.sshfs
        ]
        ++ lib.optionals isTouchscreen [
          pkgs.wvkbd
        ];

      environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
      environment.sessionVariables.XDG_MENU_PREFIX = "plasma-";
    })
  ];
}
