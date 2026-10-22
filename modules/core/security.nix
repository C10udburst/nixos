{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.core.security;
in {
  options.features.core.security = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.core.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {};
    }
    (lib.mkIf cfg.enable {
      security.pki.caCertificateBlacklist = [
        "Comodo AAA Services root"
        "emSign ECC Root CA - G3"
      ];
    })
  ];
}
