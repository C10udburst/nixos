{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.firewall;
  firewallEnabled =
    if builtins.isAttrs cfg
    then cfg.enable
    else cfg;
in {
  options.features.core.firewall = lib.mkOption {
    type = lib.types.either lib.types.bool (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
      }
    );
    default = config.features.core.enable && false;
  };

  config = {
    networking.firewall.enable =
      if firewallEnabled
      then true
      else lib.mkForce false;
    networking.nftables.enable = lib.mkIf (!firewallEnabled) (lib.mkForce false);
  };
}
