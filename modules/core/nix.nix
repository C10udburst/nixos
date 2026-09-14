{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.nix;
  isSlow = config.features.core.hardware.slow or false;
in {
  options.features.core.nix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.core.enable && true;
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
    ghcr = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        nixcache-oci = {
          url = "github:cmspam/nixcache-oci";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = lib.optionals cfg.vulnix [pkgs.vulnix];

      nix.settings = {
        experimental-features = [
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

      services.nixcache-proxy = lib.mkIf cfg.ghcr {
        enable = true;
        repo = "C10udburst/nixos";
        publicKey = "cloudburst-nixos-1:dYoYC/1hQ1OBE6ocDJgwl5dkIH3ArNtWsopCc81SEN4=";
      };

      systemd.services.nixcache-proxy.environment.NIXCACHE_UPSTREAM = lib.mkIf cfg.ghcr (
        let
          allSubstituters = lib.unique (
            (config.nix.settings.substituters or ["https://cache.nixos.org"])
            ++ (config.nix.settings.extra-substituters or [])
          );
          cleanUrl = s: lib.removeSuffix "/" s;
          upstreamSubstituters = map cleanUrl (
            builtins.filter (
              s: !lib.hasPrefix "http://localhost" s && !lib.hasPrefix "http://127.0.0.1" s
            )
            allSubstituters
          );
        in
          builtins.concatStringsSep " " upstreamSubstituters
      );

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
    })
  ];
}
