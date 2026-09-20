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
4. **Partition the drive, format filesystems, and mount to `/mnt`**:
   - Launch the interactive partition editor:
     ```bash
     tparted
     ```
     Or partition manually with `gdisk`/`parted`, format filesystems (`mkfs.ext4`, `mkfs.btrfs`, `mkfs.fat -F 32`), and mount:
     ```bash
     mount /dev/nvme0n1p2 /mnt
     mkdir -p /mnt/boot
     mount /dev/nvme0n1p1 /mnt/boot
     ```
   > [!IMPORTANT]
   > Mounting your root filesystem to `/mnt` **before** initializing is essential: it allows `nixos-generate-config` to detect your real disk UUIDs and mountpoints, and ensures the SSH host key for Agenix is written directly to `/mnt/etc/ssh/`.

---

### 3. Initialize Host Configuration (`./bootstrap init`)

From your workstation (over SSH):
```bash
./bootstrap init <ip> <hostname>
```
*Or locally from within the live environment:*
```bash
./bootstrap init <hostname>
```
*Example:*
```bash
./bootstrap init 192.168.1.50 cloudburst-new
```

**What this does automatically:**
1. Connects to the target machine over SSH (or inspects local system directly if local).
2. Extracts hardware configuration via `nixos-generate-config` (from `/mnt` if mounted or running hardware).
3. Generates the 4-file host directory in `./hosts/<hostname>/`:
   - `hardware-configuration.nix` (auto-detected hardware configuration)
   - `configuration.nix` (host plumbing, hostname, stateVersion)
   - `home-manager.nix` (host-specific user profile overrides)
   - `features.nix` (declarative dendritic feature toggles)
4. Registers the host in `outputs.nix` under `nixosConfigurations`.
5. Retrieves or generates the host's SSH public key, saves it to `/mnt/etc/ssh/`, and prints the snippet for [secrets.nix](file:///home/cloudburst/nixos/secrets.nix).
6. Formats with `alejandra` and stages changes in Git.

---

### 4. Configure Features and Secrets

#### A. Add Host Key to Secrets (Optional / Agenix)
If the host needs access to encrypted secrets (such as Samba credentials or service tokens):
1. On your **workstation** (where your personal SSH private key is present to decrypt existing secrets), open `secrets.nix`.
2. Add the host key printed by `./bootstrap init`:
```nix
# In secrets.nix:
cloudburst-new = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";

allHosts = [
  ...
  cloudburst-new # grants access to all-host secrets (e.g. SMB credentials)
];

# If this host is a server running hosted services (Gitea, Vaultwarden, etc.):
serverHosts = [
  ...
  cloudburst-new # grants access to server secrets
];
```
3. Re-encrypt secrets on your workstation:
```bash
agenix --rekey
```
*(Note: Always run `agenix --rekey` on your workstation, not in the live installer environment, since your personal decrypting SSH key is not present on the installer ISO).*

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
# Remotely from your workstation:
./bootstrap apply <ip> <hostname> [--mkrepo]

# Or locally from within the live environment:
./bootstrap apply <hostname> [--mkrepo]
```

**What this does:**
1. Builds the system closure locally.
2. **If `/mnt` is mounted (installation mode):**
   - Copies the system closure directly to `/mnt/nix/store` on the target disk (without exhausting RAM/tmpfs).
   - Runs `nixos-install --root /mnt --system ...` to install NixOS and the bootloader to `/mnt/boot`.
   - If `--mkrepo` is passed, sets up and syncs the repository into `/home/cloudburst/nixos` on the installed disk.
3. **If `/mnt` is not mounted (update mode):**
   - Pushes closure to `/nix/store` and activates the configuration via `switch-to-configuration switch`.
   - If `--mkrepo` is passed, sets up and syncs the repository into `~/nixos`.

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
