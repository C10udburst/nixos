# Proxmox LXC guest: no block devices, initrd or kernel modules to describe.
# The rootfs is a PVE volume and the kernel is the host's, so `nixos-generate-config`
# output is meaningless here (it reports the host's /dev/mapper path and kvm-intel).
{lib, ...}: {
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
