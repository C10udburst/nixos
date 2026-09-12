{
  config,
  lib,
  pkgs,
  ...
}: let
  helpers = import ../../lib {inherit config lib pkgs;};
in {
  _module.args.helpers = helpers;
  home-manager.extraSpecialArgs = {
    inherit helpers;
  };
}
