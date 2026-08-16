{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.nushell;
in {
  imports = [
    ./open.nix
    ./undo.nix
    ./modules.nix
    ./scripts.nix
  ];

  options.homeSettings.nushell = {
    enable = lib.mkEnableOption "Enable Nushell configuration";
    default = lib.mkOption {
      type = lib.types.enum [
        "all"
        "term"
        "none"
      ];
      default = "none";
      description = "Default shell strategy: 'all' to change login shell, 'term' to replace default shell for terminal emulators only, or 'none'.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      package = pkgs.nushell;
      extraConfig = ''
        $env.config.show_banner = false

        # Parsed system mount command if no arguments, otherwise normal mount
        def mount [...args: string] {
          if ($args | is-empty) {
            ^mount | parse "{device} on {path} type {type} {args}"
          } else {
            ^mount ...$args
          }
        }
      '';
    };

    # Enable Starship integration
    programs.starship.enableNushellIntegration = true;
  };
}
