{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  # Nix owns the address and hostname (no PVE networkd drop-in, no forced empty hostName)
  proxmoxLXC = {
    manageNetwork = true;
    manageHostName = true;
  };

  # Static addressing, kept in sync with the PVE ipconfig0 for this CT
  networking = {
    hostName = "nixos-lxc";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.1.81";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.1.1";

    # Unprivileged CT: keep the host resolv.conf; tailscale MagicDNS overwrites it at runtime
    resolvconf.enable = false;
    useHostResolvConf = true;

    # Let the host manage the network; the CT is unprivileged and cannot manage its own network
    networkmanager.enable = lib.mkForce false;
  };

  # services.resolved asserts against networking.useHostResolvConf
  services.resolved.enable = false;

  # Pseudo-filesystems belong to the PVE host; mounting them in an unprivileged CT fails
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  # Console login via `pct console`: the CT image ships root without a password,
  # so login(1) needs nullok (the stock PAM stack rejects it).
  security.pam.services.login.text = lib.mkDefault ''
    auth     sufficient pam_rootok.so
    auth     required   pam_unix.so nullok
    account  required   pam_unix.so
    session  required   pam_unix.so
  '';

  system.stateVersion = "26.05";
}
