# Dendritic NixOS Configuration

A modular, dendritic NixOS configuration managing workstations, laptops, tablets, and servers.

---

## Guide: Setting Up a New Host

Follow these steps to bootstrap and deploy a new machine from scratch.

### 1. Build the Bootstrap ISO

The repository provides a minimal bootstrap installation ISO featuring:
- **Dual 32-bit and 64-bit UEFI GRUB** (boots on modern PCs, Intel Atom tablets, and legacy UEFI devices alike).
- **Pre-authorized SSH**: Login directly using your configured SSH key without passwords.
- **Waypipe**: For remote Wayland graphical application forwarding.
- **Partitioning & Installation Tools**: `tparted`, `parted`, `gptfdisk`, `btrfs-progs`, `dosfstools`, `e2fsprogs`, `nixos-install-tools`, `git`, `rsync`, and more.

Build the ISO:
```bash
./bootstrap iso
# or: nix build .#iso
```
The ISO will be created in `./result/iso/`:
```bash
ls -lh ./result/iso/*.iso
```

Flash the ISO to a USB flash drive (replace `/dev/sdX` with your USB drive):
```bash
sudo dd if=$(echo ./result/iso/*.iso) of=/dev/sdX bs=4M status=progress oflag=sync
```

---

### 2. Boot & Partition the Target Machine

1. Insert the USB drive and boot the target device into UEFI boot mode.
2. The system will boot automatically into the minimal bootstrap environment.
3. Check the machine's IP address displayed on the terminal or via `ip a` (e.g., `192.168.1.50`).
4. (Optional) If you want custom partitions, launch the terminal partition editor:
   ```bash
   tparted
   ```
   Or partition with `gdisk`/`parted`, format filesystems, and mount your root partition to `/mnt` (with `/mnt/boot` or `/mnt/boot/efi` for EFI).

---

### 3. Initialize Host Configuration (`./bootstrap init`)

From your workstation (in this repository directory), run:
```bash
./bootstrap init <ip> <hostname>
```
*Example:*
```bash
./bootstrap init 192.168.1.50 cloudburst-new
```

**What this does automatically:**
1. Connects to the target machine over SSH.
2. Extracts hardware configuration via `nixos-generate-config` (from `/mnt` if mounted or running hardware).
3. Generates the 4-file host directory in `./hosts/<hostname>/`:
   - `hardware-configuration.nix` (auto-detected hardware configuration)
   - `configuration.nix` (host plumbing, hostname, stateVersion)
   - `home-manager.nix` (host-specific user profile overrides)
   - `features.nix` (declarative dendritic feature toggles)
4. Registers the host in `outputs.nix` under `nixosConfigurations`.
5. Retrieves the host's SSH public key and prints the snippet for [secrets.nix](file:///home/cloudburst/nixos/secrets.nix).
6. Formats with `alejandra` and stages changes in Git.

---

### 4. Configure Features and Secrets

#### A. Add Host Key to Secrets (Optional / Agenix)
If the host needs access to encrypted secrets (such as Samba credentials or service tokens), copy the printed key from the previous step into `secrets.nix`:
```nix
# In secrets.nix:
cloudburst-new = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";

allHosts = [
  ...
  cloudburst-new
];
```
Re-encrypt secrets:
```bash
agenix --rekey
```

#### B. Configure Features (`./hosts/<hostname>/features.nix`)
Open `./hosts/<hostname>/features.nix` and enable the desired feature set:
```nix
_: {
  features = {
    # Bootloader (defaults to systemd-boot; enable GRUB for tablets or dual-arch)
    # core.boot.grub = true;
    # core.boot.grub32 = true;

    core.hardware = {
      mobile = true; # if laptop/mobile
    };

    services = {
      tailscale.enable = true;
    };

    gui = {
      enable = true;
      desktop.driftwm.enable = true;
      apps.brave.apps.office = true;
      dev.enable = true;
    };
  };
}
```

---

### 5. Deploy Configuration (`./bootstrap apply`)

Build and apply the configuration to the target machine:
```bash
./bootstrap apply <ip> <hostname>
```

To also clone this repository to `~/nixos` on the new host upon completion:
```bash
./bootstrap apply <ip> <hostname> --mkrepo
```

**What this does:**
1. Builds the system closure locally on your workstation.
2. Pushes the closure to the target machine via `nix-copy-closure`.
3. Sets the NixOS system profile and switches to the new configuration.
4. If `--mkrepo` is passed, sets up and syncs the repository into `~/nixos` on the target machine.

---

## Daily Workflow: Managing Existing Hosts

### Rebuilding Systems (`./apply`)
Rebuild and deploy changes across one or multiple machines:
```bash
# Rebuild and switch local host
./apply switch

# Rebuild local host on next boot
./apply boot

# Rebuild and switch remote target(s)
./apply switch cloudburst-laptop cloudburst-tablet
```

### Checking Configuration
To verify flake syntax and module validity without rebuilding:
```bash
nix flake check --no-build
```

### Dry-run Build
```bash
nixos-rebuild build --flake .#<hostname>
```
