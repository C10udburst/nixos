{
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
  ];

  fileSystems."/mnt/dane" = {
    device = "/dev/disk/by-uuid/213C801055180E72";
    fsType = "lowntfs-3g";
    options = [
      "nofail"
      "rw"
      "windows_names"
      "ignore_case"
      "dmask=000"
      "fmask=000"
      "utf8"
      "noatime"
      "allow_other"
    ];
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;
  boot.loader.systemd-boot.extraInstallCommands = ''
    echo "auto-entries 0" >> ${config.boot.loader.efi.efiSysMountPoint}/loader/loader.conf
  '';
  boot.initrd.kernelModules = ["amdgpu"];
  boot.supportedFilesystems = ["ntfs"];

  networking.hostName = "cloudburst-desktop";

  # Enable Multipath TCP (MPTCP) for simultaneous Ethernet and Wi-Fi transmission
  boot.kernel.sysctl."net.mptcp.enabled" = 1;
  services.mptcpd.enable = true;

  system.stateVersion = "26.05";
}
