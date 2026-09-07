let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;

  modA = {
    config,
    lib,
    ...
  }: {
    options.features.gui.apps.brave.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  modB = {
    config,
    lib,
    ...
  }: {
    options.features.gui.apps.brave.extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["--test"];
    };
  };

  modC = {
    config,
    lib,
    ...
  }: {
    options.features.gui.apps.brave.apps.office = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  eval = lib.evalModules {
    modules = [modA modB modC];
  };
in {
  brave_enable = eval.config.features.gui.apps.brave.enable;
  brave_extraFlags = eval.config.features.gui.apps.brave.extraFlags;
  brave_apps_office = eval.config.features.gui.apps.brave.apps.office;
}
