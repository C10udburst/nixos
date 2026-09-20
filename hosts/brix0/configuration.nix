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

  networking.interfaces.enp0s31f6.ipv4.addresses = [
    {
      address = "192.168.1.10";
      prefixLength = 24;
    }
  ];
  networking.interfaces.wlp1s0.ipv4.addresses = [
    {
      address = "192.168.1.11";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.1.1";

  # Prevent ARP flux when having two interfaces on the same subnet (192.168.1.0/24)
  # and tune server network performance
  boot.kernel.sysctl = {
    # High-throughput TCP BBR congestion control
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;

    # ARP flux prevention for multi-homed subnet
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.default.arp_announce" = 2;

    "vm.vfs_cache_pressure" = 50;

    # Automatically reboot 10 seconds after kernel panic
    "kernel.panic" = 10;
  };

  # Disable Wi-Fi power saving for stable server connectivity (Intel AC-3165)
  networking.networkmanager.wifi.powersave = false;

  # Thermal management for mini-PC chassis
  services.thermald.enable = true;

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
