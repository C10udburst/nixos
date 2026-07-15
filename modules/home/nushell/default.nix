{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.nushell;
  customPlugins = import ./plugins.nix {inherit pkgs;};

  # Check if git is enabled
  gitEnabled = config.homeSettings.git.enable or false;

  # Check if adb/android is enabled
  adbEnabled =
    if builtins.isAttrs (config.hostSettings.android or false)
    then config.hostSettings.android.enable or false
    else config.hostSettings.android or false;

  # Check if openssh is enabled
  sshEnabled = config.hostSettings.openssh or false;

  # Check if gradle/kotlin/java is enabled
  gradleEnabled = (config.hostSettings.java or false) || (config.hostSettings.programming.kotlin or false);
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

      plugins = [
        #customPlugins.nu_plugin_dbus
        # customPlugins.nu_plugin_net
        # #customPlugins.nu_plugin_gstat
        # customPlugins.nu_plugin_units
        # customPlugins.nu_plugin_vec
        # customPlugins.nu_plugin_ws
        # customPlugins.nu_plugin_x509
        # customPlugins.nu_plugin_regex
        # customPlugins.nu_plugin_terminal_qr
        # customPlugins.nu_plugin_plotters
        # customPlugins.nu_plugin_json_path
        # #customPlugins.nu_plugin_hashes
        # #customPlugins.nu_plugin_format_pcap
        # customPlugins.nu_plugin_dns
      ];

      # Configure completions using nu_scripts
      extraConfig = ''
        # Load completions from nu_scripts
        use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu *
        ${lib.optionalString gitEnabled "use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/git/git-completions.nu *"}
        ${lib.optionalString adbEnabled "use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/adb/adb-completions.nu *"}
        ${lib.optionalString sshEnabled "use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/ssh/ssh-completions.nu *"}
        ${lib.optionalString gradleEnabled "use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/gradle/gradle-completions.nu *"}
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
