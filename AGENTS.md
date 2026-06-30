# Agent instructions

This repository contains the **`nixos-managing`** skill — a structured set of Markdown files that teach an AI coding agent how to safely manage NixOS systems (rebuilds, flakes, modules, deployment, impermanence, LUKS remote-unlock, monitoring).

**Any agent that understands this `AGENTS.md` convention should:**

1. Treat `nixos-managing/SKILL.md` as the entry point — it contains a decision table pointing to the right reference file for the task.
2. Load reference files on demand based on that table:
   - `configuration.md` — flakes, modules, packages, services, secrets
   - `vm-management.md` — `nixos-rebuild`, generations, rollback, remote deployment
   - `installation.md` — initial install, disko, hardware configuration
   - `image-building.md` — ISO, VM, disk images
   - `impermanence.md` — ephemeral root, wipe-on-boot
   - `luks.md` — disk encryption, remote unlock (SSH, Tailscale)
   - `anti-patterns.md` — common mistakes
3. Verify every NixOS option before suggesting it (the skill includes guidance on this — `search.nixos.org/options` is always available).
4. Ask the user about the execution context (local NixOS host vs. remote deploy from macOS/Linux) before suggesting commands.