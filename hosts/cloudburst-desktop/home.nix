{
  config,
  pkgs,
  inputs,
  ...
}: let
  hostSettings = import ./settings.nix;
in {
  imports = [
    ../../modules/home
    inputs.driftwm-noctalia.homeModules.default
  ];

  hostSettings = hostSettings;

  home.stateVersion = "26.05";
}
