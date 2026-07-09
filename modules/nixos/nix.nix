{config, ...}: {
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nix.settings.extra-substituters = [
    "https://nix-community.cachix.org"
  ];

  nix.settings.extra-trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  nix.gc = {
    automatic = true;
  };

  nix.optimise.automatic = false;
  nix.settings.warn-dirty = false;
}
