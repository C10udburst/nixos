{
  config,
  lib,
  ...
}: let
  cfg = config.features.shell.nushell;
in {
  options.features.shell.nushell.wrappers = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (config.features.shell.enable && cfg.enable && cfg.wrappers) {
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
