{config, ...}: {
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nix.gc = {
    automatic = false;
  };

  nix.optimise.automatic = false;
}
