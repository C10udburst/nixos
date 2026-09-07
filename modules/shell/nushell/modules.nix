{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.nushell;
  nuModules =
    [
      "custom-completions/nix/nix-completions.nu"
      "modules/nix/nix.nu"
      "modules/network/ssh.nu"
      "modules/network/sockets/sockets.nu"
      "modules/to-json-schema/to-json-schema.nu"
      "modules/git/git.nu"
      "modules/wc/wc.nu"
      "modules/system/mod.nu"
    ]
    ++ lib.optional (
      config.features.shell.git.enable or false
    ) "custom-completions/git/git-completions.nu"
    ++ lib.optional (
      config.features.gui.dev.android.enable or false
    ) "custom-completions/adb/adb-completions.nu"
    ++ lib.optional (
      config.features.gui.dev.android.enable or false
    ) "custom-completions/fastboot/fastboot-completions.nu"
    ++ lib.optional (
      config.features.services.openssh.enable or false
    ) "custom-completions/ssh/ssh-completions.nu"
    ++ lib.optional (
      config.features.gui.dev.programming.kotlin or false
    ) "custom-completions/gradlew/gradlew-completions.nu"
    ++ lib.optional (
      config.features.compat.podman.enable or false
    ) "custom-completions/docker/docker-completions.nu"
    ++ lib.optional (
      config.features.gui.dev.documents.typst or false
    ) "custom-completions/typst/typst-completions.nu";
in {
  options.features.shell.nushell.modules = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.shell.enable && config.features.shell.nushell.enable) && true;
  };

  config = lib.mkIf cfg.modules {
    home-manager.users.cloudburst = {
      programs.nushell.extraConfig = lib.concatStringsSep "\n" (
        map (module: "use ${pkgs.nu_scripts}/share/nu_scripts/${module} *") nuModules
      );
    };
  };
}
