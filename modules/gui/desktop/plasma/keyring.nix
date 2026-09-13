{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.desktop.plasma.keyring;
in {
  options.features.gui.desktop.plasma.keyring = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.desktop.plasma.enable && true;
  };

  config = lib.mkIf cfg {
    services.gnome.gnome-keyring.enable = lib.mkDefault true;

    # Completely disable KWallet in PAM and use GNOME Keyring instead
    security.pam.services = {
      login.kwallet.enable = lib.mkForce false;
      kde.kwallet.enable = lib.mkForce false;
      login.enableGnomeKeyring = lib.mkDefault true;
      kde.enableGnomeKeyring = lib.mkDefault true;
    };

    # Disable KWallet explicitly so KDE Frameworks never prompt for or open a wallet
    environment.etc."xdg/kwalletrc".text = ''
      [Wallet]
      Enabled=false
      First Use=false
    '';

    # Exclude kwallet, kwallet-pam, and kwalletmanager from the system profile
    system.path = lib.mkForce (
      pkgs.buildEnv {
        name = "system-path";
        paths =
          builtins.filter (
            pkg: let
              pname = pkg.pname or (builtins.parseDrvName (pkg.name or "")).name;
            in
              !builtins.elem pname [
                "kwallet"
                "kwallet-pam"
                "kwalletmanager"
              ]
          )
          config.environment.systemPackages;
        inherit (config.environment) pathsToLink extraOutputsToInstall;
        ignoreCollisions = true;
        postBuild = ''
          find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete
          find $out/bin -maxdepth 1 -name ".*-wrapped_*" -type l -delete

          if [ -x $out/bin/glib-compile-schemas -a -w $out/share/glib-2.0/schemas ]; then
              $out/bin/glib-compile-schemas $out/share/glib-2.0/schemas
          fi

          ${config.environment.extraSetup}
        '';
      }
    );

    home-manager.users.cloudburst = {
      xdg.configFile."kwalletrc".text = ''
        [Wallet]
        Enabled=false
        First Use=false
      '';
    };
  };
}
