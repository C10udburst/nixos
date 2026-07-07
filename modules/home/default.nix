{
  config,
  lib,
  ...
}: {
  imports = [
    ./git.nix
    ./jetbrains.nix
    ./llm.nix
    ./plasma.nix
    ./user.nix
    ./starship.nix
    ./tailscale.nix
    ./shell.nix
    ./driftwm
    ./ulauncher.nix
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
        tailscale.enable = lib.mkOption {type = lib.types.bool;};
        shell.enable = lib.mkOption {type = lib.types.bool;};
        ulauncher.enable = lib.mkOption {type = lib.types.bool;};
        editors.enable = lib.mkOption {type = lib.types.bool;};
        programming = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        python = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        latex = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
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
      tailscale.enable = lib.mkDefault (config.hostSettings.tailscale or false);
      shell.enable = lib.mkDefault true;
      ulauncher.enable = lib.mkDefault (config.hostSettings.ulauncher or false);
      editors.enable = lib.mkDefault (config.hostSettings.editors or false);
      programming = lib.mkDefault (config.hostSettings.programming or false);
      python = lib.mkDefault (config.hostSettings.python or false);
      latex = lib.mkDefault (config.hostSettings.latex or false);
    };
  };
}
