{
  config,
  lib,
  ...
}: let
  cfg = config.homeSettings.nushell;
in {
  config = lib.mkIf cfg.enable {
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
}
