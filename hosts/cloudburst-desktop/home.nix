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
  ];

  hostSettings = hostSettings;

  home.stateVersion = "26.05";
}
