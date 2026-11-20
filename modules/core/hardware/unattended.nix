{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.unattended = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && false;
  };

  config = lib.mkIf cfg.unattended {
    # Nobody is watching the console, so a fault has to resolve itself:
    # reboot 10s after a kernel panic, treat oopses and hard CPU lockups
    # as panics as well.
    boot.kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
      "kernel.hardlockup_panic" = 1;
    };

    # Reboot on panics in stage 2 (panic=) and on boot failures inside the
    # initrd (boot.panic_on_fail) instead of hanging on a black screen.
    boot.kernelParams = [
      "panic=10"
      "boot.panic_on_fail"
    ];

    # No interactive emergency shell on a box without a keyboard: keep
    # booting as far as possible instead of waiting for a login that never
    # comes.
    systemd.enableEmergencyMode = false;

    # Headless 24/7 duty: never fall asleep, suspend or hibernate.
    systemd.targets.sleep.enable = false;
    systemd.targets.suspend.enable = false;
    systemd.targets.hibernate.enable = false;
    systemd.targets.hybrid-sleep.enable = false;

    # Nobody logs in and stays, so user@1000.service has to outlive the
    # sessions that happen to open: without lingering it stops when the last
    # one closes and takes every user service down with it.
    users.users.cloudburst.linger = true;

    # Jump straight past the boot menu, but stay interruptible.
    features.core.boot.timeout = lib.mkDefault 1;
  };
}
