{
  config,
  lib,
  ...
}: let
  cfg = config.features.services.openssh;
in {
  options.features.services.openssh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.services.enable && true;
    };
    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh.knownHosts."github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.passwordAuthentication;
        PermitRootLogin = "no";
      };
    };
  };
}
