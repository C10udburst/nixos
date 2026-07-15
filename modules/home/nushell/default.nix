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
    ++ lib.optional (config.homeSettings.git.enable or false) "custom-completions/git/git-completions.nu"
    ++ lib.optional (config.hostSettings.android.enable or false) "custom-completions/adb/adb-completions.nu"
    ++ lib.optional (config.hostSettings.android.enable or false) "custom-completions/fastboot/fastboot-completions.nu"
    ++ lib.optional (config.hostSettings.openssh or false) "custom-completions/ssh/ssh-completions.nu"
    ++ lib.optional (config.hostSettings.java or false) "custom-completions/gradlew/gradlew-completions.nu"
    ++ lib.optional (config.hostSettings.podman or false) "custom-completions/docker/docker-completions.nu"
    ++ lib.optional (config.hostSettings.typst or false) "custom-completions/typst/typst-completions.nu";
in {
  options.homeSettings.nushell = {
    enable = lib.mkEnableOption "Enable Nushell configuration";
    default = lib.mkOption {
      type = lib.types.enum ["all" "term" "none"];
      default = "none";
      description = "Default shell strategy: 'all' to change login shell, 'term' to replace default shell for terminal emulators only, or 'none'.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      package = pkgs.nushell;
      extraConfig =
        (lib.concatStringsSep "\n" (map (module: "use ${pkgs.nu_scripts}/share/nu_scripts/${module} *") modules))
        + "\n"
        + ''
          $env.config.show_banner = false
          if 'KITTY_PID' in $env {
            $env.config.use_kitty_protocol = true
          }
        '';
    };

    # Enable Starship integration
    programs.starship.enableNushellIntegration = true;

    # Replace defaults for kitty and konsole if 'term' or 'all'
    programs.kitty.settings.shell = lib.mkIf (cfg.default == "term" || cfg.default == "all") "${pkgs.nushell}/bin/nu";

    # Configure Konsole (requires plasma-manager config files)
    xdg.dataFile."konsole/Nushell.profile".text = lib.mkIf (cfg.default == "term" || cfg.default == "all") ''
      [General]
      Command=${pkgs.nushell}/bin/nu
      Name=Nushell
      Parent=FALLBACK/
    '';

    programs.plasma.configFile."konsolerc" = lib.mkIf (cfg.default == "term" || cfg.default == "all") {
      "Desktop Entry" = {
        DefaultProfile = "Nushell.profile";
      };
    };
  };
}
