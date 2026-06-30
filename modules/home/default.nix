{
  config,
  lib,
  ...
}: {
  imports = [
    ./git.nix
    ./llm.nix
    ./plasma.nix
    ./user.nix
    ./starship.nix
    ./tailscale.nix
    ./shell.nix
    ./driftwm.nix
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
        driftwm.enable = lib.mkOption {type = lib.types.bool;};
        tailscale.enable = lib.mkOption {type = lib.types.bool;};
        shell.enable = lib.mkOption {type = lib.types.bool;};
      };
    };
    default = {};
    description = "Home manager settings";
  };

  config = {
    homeSettings = {
      user.username = lib.mkDefault (config.hostSettings.username or "cloudburst");
      git.enable = lib.mkDefault (config.hostSettings.git or false);
      plasma.enable = lib.mkDefault (config.hostSettings.plasma or false);
      llm.enable = lib.mkDefault (config.hostSettings.llm or false);
      driftwm.enable = lib.mkDefault (config.hostSettings.driftwm or false);
      tailscale.enable = lib.mkDefault (config.hostSettings.tailscale or false);
      shell.enable = lib.mkDefault true;
    };
  };
}
