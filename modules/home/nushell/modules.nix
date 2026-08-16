{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.nushell;

  modules =
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
      config.homeSettings.git.enable or false
    ) "custom-completions/git/git-completions.nu"
    ++ lib.optional (
      config.hostSettings.android.enable or false
    ) "custom-completions/adb/adb-completions.nu"
    ++ lib.optional (
      config.hostSettings.android.enable or false
    ) "custom-completions/fastboot/fastboot-completions.nu"
    ++ lib.optional (config.hostSettings.openssh or false) "custom-completions/ssh/ssh-completions.nu"
    ++ lib.optional (
      config.hostSettings.java or false
    ) "custom-completions/gradlew/gradlew-completions.nu"
    ++ lib.optional (
      config.hostSettings.podman or false
    ) "custom-completions/docker/docker-completions.nu"
    ++ lib.optional (
      config.hostSettings.typst or false
    ) "custom-completions/typst/typst-completions.nu";
in {
  config = lib.mkIf cfg.enable {
    programs.nushell.extraConfig = lib.concatStringsSep "\n" (
      map (module: "use ${pkgs.nu_scripts}/share/nu_scripts/${module} *") modules
    );
  };
}
