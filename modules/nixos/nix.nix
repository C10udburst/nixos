{
  config,
  lib,
  ...
}: let
  adminUsers = config.systemSettings.adminUsers or [];
in {
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nix.settings.extra-substituters = [
    "https://nix-community.cachix.org"
    "https://cache.nixos-cuda.org"
  ];

  nix.settings.extra-trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  nix.gc = {
    automatic = true;
  };

  nix.optimise.automatic = false;
  nix.settings.warn-dirty = false;
}
