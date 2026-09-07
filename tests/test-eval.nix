let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  dendritic = import ../lib/node.nix {inherit lib;};
  inherit (dendritic) mkDendriticNode mkDendriticLeaf;

  # Test module defining a mini hierarchy
  testModule = {config, ...}: {
    options.features.gui = mkDendriticNode {
      default = true;
      options = {
        apps = mkDendriticNode {
          parent = config.features.gui;
          default = true;
          options = {
            brave = mkDendriticNode {
              parent = config.features.gui.apps;
              default = true;
              options = {
                extraFlags = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                };
                office = mkDendriticLeaf {
                  parent = config.features.gui.apps.brave;
                  default = false; # canonical default in config-full
                };
                media = mkDendriticLeaf {
                  parent = config.features.gui.apps.brave;
                  default = true; # canonical default in config-full
                };
              };
            };
          };
        };
      };
    };
  };

  # Scenario 1: Default evaluation (parent enabled -> children take canonical defaults)
  evalDefaults = lib.evalModules {
    modules = [testModule];
  };

  # Scenario 2: Parent disabled (gui = false -> everything underneath must be false)
  evalParentDisabled = lib.evalModules {
    modules = [
      testModule
      {config.features.gui.enable = false;}
    ];
  };

  # Scenario 3: Explicit override of leaf
  evalExplicitOverride = lib.evalModules {
    modules = [
      testModule
      {
        config.features.gui.apps.brave.office = true;
        config.features.gui.apps.brave.media = false;
      }
    ];
  };

  # Scenario 4: Boolean coercion of branch
  evalCoercion = lib.evalModules {
    modules = [
      testModule
      {config.features.gui.apps.brave = true;}
    ];
  };
in {
  defaults = {
    gui_enable = evalDefaults.config.features.gui.enable;
    brave_enable = evalDefaults.config.features.gui.apps.brave.enable;
    brave_office = evalDefaults.config.features.gui.apps.brave.office;
    brave_media = evalDefaults.config.features.gui.apps.brave.media;
  };

  parentDisabled = {
    gui_enable = evalParentDisabled.config.features.gui.enable;
    apps_enable = evalParentDisabled.config.features.gui.apps.enable;
    brave_enable = evalParentDisabled.config.features.gui.apps.brave.enable;
    brave_office = evalParentDisabled.config.features.gui.apps.brave.office;
    brave_media = evalParentDisabled.config.features.gui.apps.brave.media;
  };

  explicitOverride = {
    brave_office = evalExplicitOverride.config.features.gui.apps.brave.office;
    brave_media = evalExplicitOverride.config.features.gui.apps.brave.media;
  };

  coercion = {
    brave_enable = evalCoercion.config.features.gui.apps.brave.enable;
    brave_enabled = evalCoercion.config.features.gui.apps.brave.enabled;
  };

  # Assertions to guarantee correctness
  asserts = [
    (assert evalDefaults.config.features.gui.enable == true; true)
    (assert evalDefaults.config.features.gui.apps.brave.enable == true; true)
    (assert evalDefaults.config.features.gui.apps.brave.office == false; true)
    (assert evalDefaults.config.features.gui.apps.brave.media == true; true)
    (assert evalParentDisabled.config.features.gui.enable == false; true)
    (assert evalParentDisabled.config.features.gui.apps.enable == false; true)
    (assert evalParentDisabled.config.features.gui.apps.brave.enable == false; true)
    (assert evalParentDisabled.config.features.gui.apps.brave.office == false; true)
    (assert evalParentDisabled.config.features.gui.apps.brave.media == false; true)
    (assert evalExplicitOverride.config.features.gui.apps.brave.office == true; true)
    (assert evalExplicitOverride.config.features.gui.apps.brave.media == false; true)
    (assert evalCoercion.config.features.gui.apps.brave.enable == true; true)
    (assert evalCoercion.config.features.gui.apps.brave.enabled == true; true)
  ];
}
