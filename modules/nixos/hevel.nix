{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.hevel;
in {
  options.systemSettings.hevel = {
    enable = lib.mkEnableOption "Enable hevel and mojito packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.neu-nix.packages.${pkgs.system}.hevel
      inputs.neu-nix.packages.${pkgs.system}.mojito
    ];
  };
}
