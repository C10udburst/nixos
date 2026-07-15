{
  config,
  lib,
  ...
}: {
  imports = [
    ./associations.nix
    ./dolphin
    ./driftwm
    ./git.nix
    ./jetbrains.nix
    ./llm.nix
    ./nushell
    ./plasma.nix
    ./ranger
    ./shell.nix
    ./starship.nix
    ./threed.nix
    ./ulauncher.nix
    ./user.nix
    ./vencord.nix
    ./vscode.nix
  ];

  options.hostSettings = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Loaded host settings from settings.nix";
  };

  options.homeSettings = lib.mkOption {
    type = lib.types.submodule {
      freeformType = lib.types.attrsOf lib.types.anything;
      options = {
        user.username = lib.mkOption {type = lib.types.str;};
        git.enable = lib.mkOption {type = lib.types.bool;};
        plasma.enable = lib.mkOption {type = lib.types.bool;};
        llm.enable = lib.mkOption {type = lib.types.bool;};
        shell.enable = lib.mkOption {type = lib.types.bool;};
        ulauncher.enable = lib.mkOption {type = lib.types.bool;};
        editors.enable = lib.mkOption {type = lib.types.bool;};
        programming = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              rust = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
              go = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
              node = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
              kotlin = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
            };
          };
          default = {};
        };
        python = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        latex = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        typst = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        arduino = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              boards = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = ["arduino"];
              };
            };
          };
          default = {};
        };
        vencord.enable = lib.mkOption {type = lib.types.bool;};
      };
    };
    default = {};
    description = "Home manager settings";
  };

  config = {
    homeSettings = {
      user.username = lib.mkDefault (config.hostSettings.username or "cloudburst");
      git.enable = lib.mkDefault (config.hostSettings.git or false);
      jetbrains.enable = lib.mkDefault (config.hostSettings.jetbrains or false);
      plasma.enable = lib.mkDefault (config.hostSettings.plasma or false);
      llm.enable = lib.mkDefault (config.hostSettings.llm or false);
      driftwm.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.driftwm or false)
        then config.hostSettings.driftwm.enable or false
        else config.hostSettings.driftwm or false
      );
      driftwm.extracmds = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.driftwm or false)
        then config.hostSettings.driftwm.extracmds or []
        else []
      );
      shell.enable = lib.mkDefault true;
      ulauncher.enable = lib.mkDefault (config.hostSettings.ulauncher or false);
      editors.enable = lib.mkDefault (config.hostSettings.editors or false);
      programming.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.enable or false
        else config.hostSettings.programming or false
      );
      programming.rust = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.rust or true
        else true
      );
      programming.go = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.go or true
        else true
      );
      programming.node = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.node or true
        else true
      );
      programming.kotlin = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.kotlin or true
        else true
      );
      python = lib.mkDefault (config.hostSettings.python or false);
      latex = lib.mkDefault (config.hostSettings.latex or false);
      typst = lib.mkDefault (config.hostSettings.typst or false);
      arduino.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.arduino or false)
        then config.hostSettings.arduino.enable or false
        else config.hostSettings.arduino or false
      );
      arduino.boards = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.arduino or false)
        then config.hostSettings.arduino.boards or ["arduino"]
        else ["arduino"]
      );
      threed = lib.mkDefault (config.hostSettings.threed or false);
      vencord.enable = lib.mkDefault (config.hostSettings.vencord or false);
      associations.enable = lib.mkDefault true;
      nushell.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.nushell or false)
        then config.hostSettings.nushell.enable or false
        else config.hostSettings.nushell or false
      );
      nushell.default = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.nushell or false)
        then config.hostSettings.nushell.default or "none"
        else "none"
      );
    };
  };
}
