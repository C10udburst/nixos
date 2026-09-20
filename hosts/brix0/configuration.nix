{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "brix0";

  # EFI bootloader mount point
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # Server optimizations: headless 24/7 operation (Gigabyte BRIX Skylake i3-6100U)
  # Disable power-saving sleep/suspend states that disrupt servers
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Server network & kernel performance tuning
  boot.kernel.sysctl = {
    # High-throughput TCP BBR congestion control
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;

    "vm.vfs_cache_pressure" = 50;

    # Automatically reboot 10 seconds after kernel panic
    "kernel.panic" = 10;
  };

  # Reboot on initrd failure
  boot.kernelParams = [
    "panic=10"
    "boot.panic_on_fail"
  ];

  # Intel VA-API hardware acceleration (Intel HD Graphics 520) for media & transcoding
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };

  # Ensure storage directories exist for server services (Samba / dane)
  systemd.tmpfiles.rules = [
    "d /opt/dane 0775 cloudburst users - -"
  ];

  system.stateVersion = "26.05";
}
