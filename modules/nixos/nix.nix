{
  config,
  lib,
  inputs,
  ...
}: {
  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
    (final: prev: {
      driftwm = inputs.driftwm.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
        # The upstream flake has doCheck = true which runs a full headless
        # Wayland compositor test harness. That hangs indefinitely inside
        # the sandboxed nix build environment (no udev/DRM/sockets), so
        # we skip the check phase entirely.
        doCheck = false;
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  nix.settings.extra-substituters = [
    "https://nix-community.cachix.org"
    "https://cache.nixos-cuda.org"
    "https://hyprland.cachix.org"
    "https://numtide.cachix.org"
    "https://noctalia.cachix.org"
  ];

  nix.settings.extra-trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "numtide.cachix.org-1:psk1bDfU1UhVfiVNyPCxyhR+FtmpNkamWT0DwIK+jic="
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  nix.gc = {
    automatic = true;
    dates = lib.mkDefault (
      if config.hostSettings.slow or false
      then "daily"
      else "weekly"
    );
    options = lib.mkDefault (
      if config.hostSettings.slow or false
      then "--delete-older-than 3d"
      else "--delete-older-than 7d"
    );
  };

  nix.optimise.automatic = lib.mkDefault (config.hostSettings.slow or false);
  nix.settings.auto-optimise-store = lib.mkDefault (config.hostSettings.slow or false);
  nix.settings.warn-dirty = false;
}
