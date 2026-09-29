{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.avatar;

  accountsserviceUserFile = pkgs.writeText "cloudburst-accountsservice" ''
    [User]
    Icon=/var/lib/AccountsService/icons/cloudburst
    SystemAccount=false
  '';
in {
  options.features.gui.avatar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.enable && true;
    };

    file = lib.mkOption {
      type = lib.types.path;
      default = ./avatar.png;
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. User home icons (~/.face, ~/.face.icon) & Noctalia shell avatar
    home-manager.users.cloudburst = lib.mkMerge [
      {
        home.file.".face".source = cfg.file;
        home.file.".face.icon".source = cfg.file;
      }
      (lib.mkIf (config.features.gui.desktop.driftwm.noctalia.enable or false) {
        programs.noctalia.settings.shell.avatar_path = "${cfg.file}";
      })
    ];

    # 2. SDDM faces directory via environment.etc
    services.displayManager.sddm.settings.Theme.FacesDir = lib.mkDefault "/etc/sddm/faces";
    environment.etc."sddm/faces/cloudburst.face.icon".source = cfg.file;

    # 3. AccountsService daemon (SDDM, KDE Plasma 6, GDM, etc.)
    services.accounts-daemon.enable = true;

    systemd.tmpfiles.rules = [
      "d /var/lib/AccountsService/icons 0775 root root -"
      "d /var/lib/AccountsService/users 0700 root root -"
      "L+ /var/lib/AccountsService/icons/cloudburst - - - - ${cfg.file}"
      "C+ /var/lib/AccountsService/users/cloudburst 0600 root root - ${accountsserviceUserFile}"
    ];
  };
}
