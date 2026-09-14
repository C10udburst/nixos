{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.tmpdir;
in {
  options.features.core.tmpdir = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.enable && true;
  };

  config = lib.mkIf cfg {
    systemd.tmpfiles.rules = [
      "q /tmp 1777 root root abcmBM:7d"
      "q /var/tmp 1777 root root abcmBM:30d"
      "x /tmp/.*-unix"
      "x /tmp/systemd-private-%b-*"
      "X /tmp/systemd-private-%b-*/tmp"
    ];
  };
}
