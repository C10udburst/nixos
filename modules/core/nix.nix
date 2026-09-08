{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.core.nix;
  isSlow = config.features.core.hardware.slow or false;
  isGui = config.features.gui.enable;
in {
  options.features.core.nix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.core.enable && true;
    };
    flakes = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    autoOptimise = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    gc = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    vulnix = lib.mkOption {
      type = lib.types.bool;
      default =
        if isSlow
        then false
        else true;
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = lib.optionals cfg.vulnix [pkgs.vulnix];

    nixpkgs.overlays = lib.optionals isGui (
      lib.optionals (inputs ? nix-vscode-extensions && inputs.nix-vscode-extensions ? overlays) [
        inputs.nix-vscode-extensions.overlays.default
      ]
      ++ [
        (_final: prev: {
          driftwm =
            if inputs ? driftwm && inputs.driftwm ? packages && inputs.driftwm.packages ? ${prev.stdenv.hostPlatform.system}
            then
              inputs.driftwm.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
                doCheck = false;
              })
            else prev.driftwm or null;
        })
      ]
    );

    nix.settings = {
      experimental-features = lib.optionals cfg.flakes [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos-cuda.org"
        "https://hyprland.cachix.org"
        "https://numtide.cachix.org"
        "https://noctalia.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "numtide.cachix.org-1:psk1bDfU1UhVfiVNyPCxyhR+FtmpNkamWT0DwIK+jic="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
      auto-optimise-store = cfg.autoOptimise;
      warn-dirty = false;
    };

    nix.gc = lib.mkIf cfg.gc {
      automatic = true;
      dates =
        if isSlow
        then "daily"
        else "weekly";
      options =
        if isSlow
        then "--delete-older-than 3d"
        else "--delete-older-than 7d";
    };

    nix.optimise.automatic = cfg.autoOptimise && isSlow;
  };
}
