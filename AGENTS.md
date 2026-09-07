# Dendritic Architecture Guide for AI Agents

Welcome to the dendritic NixOS configuration repository. This document serves as the authoritative specification and operating manual for any AI agent or developer maintaining or modifying this system.

---

## 1. Architectural Philosophy: The Dendritic Pattern

Traditional NixOS configurations often suffer from **host-centric fragmentation** and **matrix proliferation**:
- System settings (`nixos/`) and user dotfiles (`home-manager/`) are split into disjoint directories.
- Hosts configure themselves by toggling flat booleans in `settings.nix`, requiring hundreds of lines of glue logic in `default.nix` files.
- Adding a feature requires editing multiple separate files across system modules, home modules, and host configs.

The **dendritic pattern** (from Greek *dendron* = tree) reorganizes the codebase into an organic, hierarchical tree of concerns:

1. **Feature-Centric Organization**:
   Code is structured around *what a feature does* (e.g., `gui/brave`, `shell/nushell`, `gui/theme`), not *where it runs* or *which tool evaluates it*.
2. **Co-located Configurations**:
   A single module file contains everything needed for a feature:
   - External dependencies (`flake-file.inputs`)
   - System-level settings (`nixos` / `environment.systemPackages`, etc.)
   - User-level environment (`home-manager.users.<user> = { ... };`)
   - Fully implicit tree discovery via `import-tree` (no manual `imports = [ ... ]` needed)
3. **Tree-Structured Composition**:
   Modules form a hierarchical tree under the `features` namespace (`core`, `services`, `shell`, `gui`, `compat`, `server`). Enabling a parent node can automatically activate its children according to canonical defaults, while still permitting fine-grained subtree selection.
4. **Automatic Discovery & Minimal Entry Points**:
   All modules in `./modules/` are recursively imported via `inputs.import-tree`. Entry points like `flake.nix` contain no manual list of module paths and can be regenerated declaratively using `flake-file`.

---

## 2. Tree Hierarchy & Directory Layout

```
features
 ├── core                  # Base system bootstrap
 │    ├── nix              # Nix daemon, flakes, caches, gc
 │    ├── users            # User accounts, ssh keys, groups
 │    ├── locale           # Timezone, locale, i18n
 │    ├── boot             # Bootloader, initrd, kernel
 │    └── hardware         # Hardware traits (mobile, touchscreen, slow, etc.)
 ├── services              # System daemons & network services (not full server stacks)
 │    ├── tailscale        # Tailscale mesh VPN daemon & exit-node
 │    ├── openssh          # OpenSSH daemon
 │    ├── waypipe          # Remote Wayland application streaming
 │    ├── weylus           # Touchscreen tablet mirror & stylus input
 │    └── usbip            # USB-over-IP daemon
 ├── shell                 # Terminal environments
 │    ├── nushell          # Nushell shell, modules, scripts
 │    ├── starship         # Starship prompt
 │    ├── git              # Git config, credentials, LFS
 │    ├── ranger           # Terminal file manager
 │    ├── scripts          # Categorized CLI utilities (media, dev, hardware, documents)
 │    └── utils            # CLI package sets (modernCli, fun, nettools)
 ├── gui                   # Graphical environment
 │    ├── desktop          # Compositors & desktop environments
 │    │    ├── driftwm     # DriftWM compositor, desktop package & noctalia shell
 │    │    └── plasma      # KDE Plasma 6
 │    ├── greeter          # Display manager (greetd / tuigreet)
 │    ├── theme            # Stylix theming engine (core, wallpaper, font)
 │    ├── apps             # Desktop applications
 │    │    ├── brave       # Brave browser & categorized webapps
 │    │    ├── editors     # VSCode, JetBrains (dynamic per lang), LibreOffice & PDF
 │    │    └── tools       # Dolphin, Konsole, OBS, social, MIME associations
 │    └── dev              # Workstation developer toolchains & environments
 │         ├── programming # Languages (rust, go, node, kotlin)
 │         ├── python      # Python stacks (dataScience, AI/CUDA, utils)
 │         ├── arduino     # Arduino IDE & board udev rules
 │         ├── documents   # LaTeX & Typst
 │         ├── threed      # Blender, OrcaSlicer, FreeCAD, OpenSCAD
 │         └── android     # Android SDK, adb, udev rules & scrcpy
 ├── compat                # Compatibility, containerization & virtualization
 │    ├── wine             # Wine compatibility layer & declarative registry styling
 │    ├── distrobox        # Distrobox containers
 │    ├── waydroid         # Waydroid Android container emulation
 │    ├── podman           # Podman rootless container runtime & docker-compat
 │    └── kvm              # QEMU / KVM virtualization & virt-manager
 └── server                # Server daemons & network sharing
      ├── samba            # Samba network file sharing
      └── westonRdp        # Weston RDP server
```

---

## 3. Anatomy of a Dendritic Module

Every module in `./modules/` is automatically discovered by `import-tree`. **Never declare manual `imports = [ ... ]`**. Here is the canonical anatomy:

```nix
{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.features.gui.apps.brave;
in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # 1. Co-located Flake Inputs (Managed by flake-file)
  # ─────────────────────────────────────────────────────────────────────────────
  # Any input required solely by this feature is declared right here.
  # Run `nix run .#write-flake` to regenerate root flake.nix.
  flake-file.inputs = {
    webicons = {
      url = "github:C10udburst/webicons-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # 2. Dendritic Option Definitions (Imports are 100% implicit via import-tree)
  # ─────────────────────────────────────────────────────────────────────────────
  options.features.gui.apps.brave = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    extraCliFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  # ─────────────────────────────────────────────────────────────────────────────
  # 3. System (NixOS) and User (Home Manager) Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {
    # System-level NixOS packages & policies
    environment.systemPackages = [ pkgs.brave ];
    environment.etc."brave/policies/managed/GroupPolicy.json".text = builtins.toJSON {
      PasswordManagerEnabled = false;
      SpellcheckEnabled = true;
      BraveRewardsDisabled = true;
    };

    # User-level Home Manager MIME bindings
    home-manager.users.cloudburst = {
      xdg.mimeApps.defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
      };
    };
  };
}
```

And in a child submodule, such as `./apps/office.nix`:

```nix
{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.features.gui.apps.brave.apps.office;
  icons = inputs.webicons.packages.${pkgs.system};
in
{
  # No manual imports required! Discovered automatically by import-tree.
  options.features.gui.apps.brave.apps.office = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [
      (pkgs.makeDesktopItem {
        name = "webapp-google-docs";
        desktopName = "Google Docs";
        exec = "brave --app=https://docs.google.com/document";
        icon = icons.google-docs;
      })
    ];
  };
}
```

---

## 4. Activation Rules, Defaults & Gating Semantics

Every feature in the dendritic configuration tree is governed by strict parent-child gating and canonical defaults:

### The Fundamental Rule: Gating + `config-full.nix` Defaults
1. **If Parent is `false` (`parent.enable == false`)**:
   - **All child submodules are `false`**. A disabled branch never activates any of its descendants.
2. **If Parent is `true` (`parent.enable == true`)**:
   - Submodules do **NOT** blindly cascade to `true`.
   - Instead, each child submodule adopts its **canonical default value as defined in `config-full.nix`**!
   - `config-full.nix` is the single source of truth for all module defaults.
3. **Explicit Host Overrides**:
   - Specifying an explicit boolean (e.g. `compat.podman.enable = true;` or `gui.apps.tools.dolphin = false;`) takes highest precedence over the canonical default.

### Concrete Examples

#### Example 1: Enabling `gui.apps.tools`
In `config-full.nix`, `tools` is defined with:
```nix
tools = {
  enable = true;
  dolphin = true;
  konsole = true;
  obs = false;
  social = {
    enable = false; # off by default, but when true, its apps default to true
    vesktop = true;
    telegram = true;
    signal = true;
  };
};
```
- If `gui.apps.tools.enable = false;`, all tools (dolphin, konsole, obs, social, associations) are **`false`**.
- If `gui.apps.tools.enable = true;`, `dolphin` and `konsole` default to **`true`**, while `obs` and `social.enable` default to **`false`**.
- If `gui.apps.tools.social.enable = true;`, then `vesktop`, `telegram`, and `signal` default to **`true`**.

#### Example 2: Enabling `compat`
In `config-full.nix`, `compat` is defined with:
```nix
compat = {
  enable = true;
  wine = false;
  distrobox = false;
  waydroid = false;
  podman = {
    enable = false;
    dockerCompat = true;
  };
  kvm = {
    enable = false;
  };
};
```
- Setting `compat = true;` (or `compat.enable = true;`) enables the compatibility subsystem, but its heavy runtime children (`wine`, `distrobox`, `waydroid`, `podman.enable`, `kvm.enable`) default to **`false`**.
- To activate Podman, the host explicitly declares `compat.podman.enable = true;`. When enabled, `dockerCompat` defaults to **`true`** (per `config-full.nix`).

#### Example 3: Enabling `gui.dev`
- In `config-full.nix`, `gui.dev.enable` is `false`.
- If a host sets `gui.dev.enable = true;`:
  - `python.enable` defaults to **`true`**, while `programming.enable`, `arduino.enable`, `threed.enable`, `documents.latex`, and `android.enable` default to **`false`**.
  - Child tool options inside `python` (`dataScience`, `ai`, `utils`) default to **`false`**.

### How This Works in `lib/node.nix`
The dendritic engine coordinates this via conditional defaults:
```nix
# Child enable definition inside mkDendriticNode
enable = lib.mkOption {
  type = lib.types.bool;
  default = if parent.enable then canonicalDefault else false;
};
```
- Both `.enable` and `.enabled` are supported symmetrically.
- Coerced boolean syntax (`compat = true;`) sets `compat.enable = true;`, leaving all child options to take their respective canonical defaults.

---

## 5. Tooling & Workflow: `flake-file` and `import-tree`

### Automatic Module Discovery (`import-tree`)
- The root flake evaluates `(inputs.import-tree ./modules)`.
- Every `.nix` file inside `modules/` is imported automatically.
- **Convention**: Any auxiliary file, template, or helper that is NOT a NixOS module MUST have its filename or enclosing folder prefixed with an underscore `_` (e.g. `_templates/`, `_helpers.nix`) to prevent `import-tree` from evaluating it as a module.

### Regenerating `flake.nix` (`flake-file`)
Never manually edit the inputs in `flake.nix`. When adding or changing a flake input:
1. Declare the input in the relevant module:
   ```nix
   flake-file.inputs.noctalia = {
     url = "github:noctalia-dev/noctalia";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
2. Run the generator script:
   ```bash
   nix run .#write-flake
   ```
3. To check if `flake.nix` is up to date in CI/checks:
   ```bash
   nix run .#write-flake -- --check
   ```

### Module Scaffolding Helper (`./mkmodule`)
To accelerate creating new dendritic modules and avoid manual boilerplate writing or typos in directory nesting:
```bash
./mkmodule features.gui.apps.brave
# Outputs: modules/gui/apps/brave/default.nix
```
- **Normalizes Path**: Strips `features.` or `config.features.` prefixes.
- **Creates Interim Folders**: Automatically runs `mkdir -p` for all missing parent directories.
- **Scaffolds Boilerplate**: Emits a valid module with inputs/arguments, options under `options.features.<path>`, and conditional `config` block.
- **Prints Output Path**: Returns the relative file path to `stdout` for chaining into tools or editors.

---

## 6. Standard Host Architecture: The 4-File Pattern

Each host directory under `hosts/<hostname>/` is organized into four distinct files, ensuring clear separation of concerns:

1. **`hardware-configuration.nix`** *(Autogenerated)*:
   - Generated by `nixos-generate-config`.
   - Contains raw hardware scan: detected kernel modules, CPU microcode, and root filesystem mounts.
   - Should never be manually cluttered with user applications or services.

2. **`home-manager.nix`** *(Tiny Skeleton File)*:
   - The user-level Home Manager entry point for the primary user.
   - Sets `home.stateVersion = "26.05";` and contains only machine-unique user overrides if any.
   - All actual dotfiles, packages, and desktop tools are automatically injected into this user profile by the dendritic dispatcher from active `features.*` submodules.

3. **`configuration.nix`** *(NixOS Plumbing)*:
   - The standard NixOS system entry point.
   - Imports:
     - `./hardware-configuration.nix`
     - `./features.nix` (the dendritic feature tree)
     - `inputs.home-manager.nixosModules.default`
     - Any machine-specific hardware flakes (e.g. `nixos-hardware`)
   - Configures host-specific essentials: `networking.hostName`, `system.stateVersion`, machine-specific disk mounts (e.g. `/mnt/dane`), and hardware quirks (such as MPTCP or proprietary drivers).

4. **`features.nix`** *(Pure Dendritic Configuration)*:
   - Contains the entire feature tree declaration (`features = { ... };`).
   - Purely declarative toggles for features, cascading theming, desktop options, webapps, development toolchains, and servers.
   - See `proto/config-full.nix` for an exhaustive reference of all available feature nodes.

---

## 7. Rules & Best Practices for Future Agents

1. **Dry-Run Rule (Crucial)**:
   Never run commands that modify the host system state (`nixos-rebuild switch`, etc.). The human operator will review and apply configurations. Agents may only perform syntax checks and dry runs:
   ```bash
   nix flake check
   nixos-rebuild dry-run --flake .#cloudburst-desktop
   ```
2. **Co-locate Related Assets**:
   Keep templates, icons, and shell scripts close to the module that uses them:
   ```
    modules/gui/desktop/driftwm/
    ├── default.nix
    ├── desktop.nix
    ├── noctalia.nix
    └── _wallpaper.glsl
   ```
3. **Custom CLI Utilities**:
   Per repository instructions, small custom CLI utilities belong in `scripts/` (or `modules/shell/scripts/`) and must be exposed as packages in `default.nix`.
4. **No SpecialArgs Proliferation**:
   Do not pass arbitrary variables down through `specialArgs` or `extraSpecialArgs`. Everything is accessible via `config.features.<branch>.<node>`.
5. **Verify Options Before Recommending**:
   Always verify NixOS option names against `search.nixos.org/options` or via `nix eval`. Avoid hallucinating non-existent options.
6. **No Redundant Option Descriptions**:
   Do NOT add `description = "..."` attributes to dendritic options or module stubs. Keep options clean, minimal, and free of redundant docstrings.
7. **No Manual Module Imports**:
   Never declare `imports = [ ... ]` in module files under `./modules/`. `import-tree` automatically discovers all `.nix` files recursively. All imports are 100% implicit.
