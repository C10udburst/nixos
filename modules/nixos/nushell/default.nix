{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.nushell;
in {
  options.systemSettings.nushell = {
    enable = lib.mkEnableOption "Enable Nushell";
    default = lib.mkOption {
      type = lib.types.enum ["all" "term" "none"];
      default = "none";
      description = "Whether Nushell is the default shell: 'all' for system login shell, 'term' for terminal emulators only, or 'none'.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.nushell];
    environment.shells = [pkgs.nushell];

    users.users = lib.mkIf (cfg.default == "all") (
      lib.genAttrs (config.systemSettings.users ++ config.systemSettings.adminUsers) (username: {
        shell = pkgs.nushell;
      })
    );
  };
}
