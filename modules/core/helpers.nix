{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  helpers = import ../../lib {inherit config lib pkgs;};
  pkgsUnstable =
    if inputs ? nixos-unstable
    then
      import inputs.nixos-unstable {
        inherit (pkgs.stdenv.hostPlatform) system;
        inherit (config.nixpkgs) config;
      }
    else pkgs;
in {
  _module.args.helpers = helpers;
  _module.args.pkgsUnstable = pkgsUnstable;
  home-manager.extraSpecialArgs = {
    inherit helpers pkgsUnstable;
  };
}
