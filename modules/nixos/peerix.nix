{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.peerix;
in {
  imports = [
    inputs.peerix.nixosModules.peerix
  ];

  options.systemSettings.peerix = {
    enable = lib.mkEnableOption "p2p local network caching with peerix";
    publicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "localhost:3um3wQmzMu2JmlzxlEsxP9/OEkqRuNrs7bAFy9iDBoQ=";
      description = "The public key to sign the derivations with.";
    };
    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = "/etc/nixos/peerix-private";
      description = "File containing the private key to sign the derivations with.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.peerix = {
      enable = true;
      package = inputs.peerix.packages.${pkgs.system}.peerix;
      publicKey = cfg.publicKey;
      privateKeyFile = cfg.privateKeyFile;
      openFirewall = true;
    };
  };
}
