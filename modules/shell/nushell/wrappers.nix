{
  config,
  lib,
  ...
}: let
  cfg = config.features.shell.nushell;
in {
  options.features.shell.nushell.wrappers = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.nushell.enable && true;
  };

  config = lib.mkIf cfg.wrappers {
    home-manager.users.cloudburst = {
      programs.nushell.extraConfig = ''
        @complete external
        def --wrapped mount [...args] {
          if ($args | is-empty) {
            ^mount | parse "{device} on {path} type {type} {args}"
          } else {
            ^mount ...$args
          }
        }
      '';
    };
  };
}
