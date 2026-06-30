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
  ];

  options.hostSettings = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Loaded host settings from settings.nix";
  };

  config.homeSettings = {
    user.username = lib.mkDefault (config.hostSettings.username or "cloudburst");
    git.enable = lib.mkDefault (config.hostSettings.git or false);
    plasma.enable = lib.mkDefault (config.hostSettings.plasma or false);
    llm.enable = lib.mkDefault (config.hostSettings.llm or false);
    tailscale.enable = lib.mkDefault (config.hostSettings.tailscale or false);
  };
}
