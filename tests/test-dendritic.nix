let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;

  mkDendriticNode = {
    parent ? null,
    canonicalDefault ? true,
    options ? {},
    ...
  }:
    lib.mkOption {
      type = lib.types.coercedTo lib.types.bool (b: {enable = b;}) (lib.types.submodule ({config, ...}: {
        options =
          {
            enable = lib.mkOption {
              type = lib.types.bool;
              default =
                if parent != null
                then
                  (
                    if parent.enable
                    then canonicalDefault
                    else false
                  )
                else canonicalDefault;
            };
            enabled = lib.mkOption {
              type = lib.types.bool;
              default = config.enable;
            };
          }
          // options;
      }));
      default = {};
    };

  # Test module evaluation
  eval1 = lib.evalModules {
    modules = [
      ({config, ...}: {
        options.features.gui = mkDendriticNode {
          canonicalDefault = true;
          options = {
            apps = mkDendriticNode {
              parent = config.features.gui;
              canonicalDefault = true;
              options = {
                brave = mkDendriticNode {
                  parent = config.features.gui.apps;
                  canonicalDefault = true;
                  options = {
                    extraFlags = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [];
                    };
                  };
                };
              };
            };
          };
        };

        config.features.gui.apps.brave = true;
      })
    ];
  };

  eval2 = lib.evalModules {
    modules = [
      ({config, ...}: {
        options.features.gui = mkDendriticNode {
          canonicalDefault = true;
          options = {
            apps = mkDendriticNode {
              parent = config.features.gui;
              canonicalDefault = true;
              options = {
                brave = mkDendriticNode {
                  parent = config.features.gui.apps;
                  canonicalDefault = true;
                };
              };
            };
          };
        };

        # Disable parent
        config.features.gui.enable = false;
      })
    ];
  };
in {
  eval1_brave_enable = eval1.config.features.gui.apps.brave.enable;
  eval1_brave_enabled = eval1.config.features.gui.apps.brave.enabled;
  eval2_gui_enable = eval2.config.features.gui.enable;
  eval2_apps_enable = eval2.config.features.gui.apps.enable;
  eval2_brave_enable = eval2.config.features.gui.apps.brave.enable;
}
