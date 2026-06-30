# NixOS VM Management

## Contents
- nixos-rebuild reference
- Generations and rollback
- Remote deployment
- Safe remote deploy workflow

---

## nixos-rebuild Full Reference

```bash
# Flake target syntax
nixos-rebuild <command> --flake .#hostname

# Channel target syntax (legacy)
nixos-rebuild <command>
```

| Command | Effect | Bootloader updated |
|---|---|---|
| `switch` | Build + activate now + set default boot | Yes |
| `test` | Build + activate now | No — safe for testing |
| `boot` | Build + set default boot | Yes — activates on next reboot |
| `build` | Build only, `./result` symlink | No |
| `dry-activate` | Print what would change | No |
| `build-vm` | Build QEMU VM | No |
| `list-generations` | Show all generations | No |
| `switch --rollback` | Activate previous generation | Yes |

**Useful flags:**
```bash
--target-host root@192.168.1.10    # activate on remote host
--build-host localhost               # build locally, send closure to target
--use-substitutes                    # let target fetch from binary cache (faster)
--fast                               # skip build if unchanged
--show-trace                         # verbose Nix errors
-v                                   # verbose output
```

---

## Generations

```bash
# List generations
nixos-rebuild list-generations
# or
nix-env --list-generations -p /nix/var/nix/profiles/system

# Roll back to previous generation
nixos-rebuild switch --rollback

# Roll back to specific generation
sudo /nix/var/nix/profiles/system-42-link/bin/switch-to-configuration switch

# Delete old generations (keep last 5)
sudo nix-env --delete-generations +5 -p /nix/var/nix/profiles/system
# or via gc options:
sudo nix-collect-garbage -d    # remove ALL old generations (destructive!)
```

**At boot**: Use GRUB/systemd-boot menu to select a previous generation. This is the safety net — always keep a few generations.

Limit boot entries to prevent `/boot` from filling up:
```nix
boot.loader.systemd-boot.configurationLimit = 10;
```

---

## Remote Deployment

### Simple: nixos-rebuild --target-host

```bash
nixos-rebuild switch \
  --flake .#myhostname \
  --target-host root@192.168.1.10 \
  --build-host localhost \
  --use-substitutes
```

SSH key must be available. Target must have Nix installed (NixOS).

### deploy-rs (Auto-rollback)

```nix
# flake.nix outputs
deploy.nodes.server1 = {
  hostname = "server1.example.com";
  profiles.system = {
    user = "root";
    path = deploy-rs.lib.x86_64-linux.activate.nixos
             self.nixosConfigurations.server1;
  };
};
```

```bash
nix run github:serokell/deploy-rs -- .#server1
nix run github:serokell/deploy-rs -- .#     # deploy all nodes
```

Auto-rollback fires if the new generation fails health checks within the timeout.

**Never test SSH config changes with switch directly** — always use `test` first.
