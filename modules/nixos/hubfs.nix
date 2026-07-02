{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.hubfs;
  hubfs = pkgs.buildGoModule rec {
    pname = "hubfs";
    version = "master";
    src = pkgs.fetchFromGitHub {
      owner = "winfsp";
      repo = "hubfs";
      rev = "master";
      hash = "sha256-Z3H37F2juYPSgwHSk2FWhPK2XZ/vy1s1/1dZPl8I+Bo=";
    };
    modRoot = "src";
    postPatch = "rm -f src/pvt src/pvt_ent.go";
    vendorHash = "sha256-AB3QTzlkStVmKgmqLeZVhjUYIr9ZIb/ZuSbdisDBtxg=";
    nativeBuildInputs = [pkgs.pkg-config];
    buildInputs = [pkgs.fuse];
    doCheck = false;
  };
in {
  options.systemSettings.hubfs = {
    enable = lib.mkEnableOption "Enable HubFS Git FUSE mountpoint";
  };

  config = lib.mkIf cfg.enable {
    programs.fuse.userAllowOther = true;

    systemd.tmpfiles.rules = [
      "d /mnt/git 0755 ${config.hostSettings.username} users - -"
    ];

    systemd.user.services.hubfs = {
      description = "HubFS FUSE mount for GitHub";
      wantedBy = ["default.target"];
      serviceConfig = {
        ExecStart = "${hubfs}/bin/hubfs -o allow_other /mnt/git";
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/git";
        Restart = "on-failure";
        Type = "simple";
      };
    };

    environment.systemPackages = [
      hubfs
    ];
  };
}
