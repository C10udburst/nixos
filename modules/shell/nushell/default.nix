{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.nushell;
  plotScript = pkgs.writeText "plot.py" (builtins.readFile ./_plot.py);
  pdScript = pkgs.writeText "pd.py" (builtins.readFile ./_pd.py);
  gridviewScript = pkgs.writeText "gridview.py" (builtins.readFile ./_gridview.py);
in {
  options.features.shell.nushell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.shell.enable && true;
    };
    default = lib.mkOption {
      type = lib.types.enum [
        "all"
        "term"
        "none"
      ];
      default = "term";
    };
    scripts = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  options.programs.nix-index = {
    enableNushellIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nushell
      pkgs.carapace
    ];
    environment.shells = [pkgs.nushell];

    users.users = lib.mkIf (cfg.default == "all") {
      cloudburst.shell = pkgs.nushell;
    };

    home-manager.users.cloudburst = {
      programs.nushell = {
        enable = true;
        package = pkgs.nushell;
        extraConfig =
          ''
            $env.config.show_banner = false
          ''
          + lib.optionalString (config.programs.nix-index.enable && config.programs.nix-index.enableNushellIntegration) ''
            $env.config.hooks.command_not_found = (source ${config.programs.nix-index.package}/etc/profile.d/command-not-found.nu)
          ''
          + lib.optionalString (cfg.scripts && (config.features.gui.enable or false)) ''
            def gridview [] {
              let input = $in
              if ($input | is-empty) { return }
              $input | to json | python3 ${gridviewScript}
            }
          ''
          + lib.optionalString cfg.scripts ''
            def treeview [] {
              let input = $in
              if ($input | is-empty) { return }
              $input | to json | jless -N
            }

            def plot [
              col_x: any,
              col_y?: any
            ] {
              let data = $in
              let x_label = if ($col_x | describe) == "closure" { "x" } else { $col_x }
              let x_vals = if ($col_x | describe) == "closure" {
                $data | each { |row| $row | do $col_x }
              } else {
                $data | get $col_x
              }
              if $col_y == null {
                let y_vals = if ($col_x | describe) == "closure" {
                  $data | each { |row| $row | do $col_x }
                } else {
                  $data | get $col_x
                }
                python3 ${plotScript} (0..(($x_vals | length) - 1) | to json -r) ($x_vals | to json -r) "Index" $x_label
              } else {
                let y_label = if ($col_y | describe) == "closure" { "y" } else { $col_y }
                let y_vals = if ($col_y | describe) == "closure" {
                  $data | each { |row| $row | do $col_y }
                } else {
                  $data | get $col_y
                }
                python3 ${plotScript} ($x_vals | to json -r) ($y_vals | to json -r) $x_label $y_label
              }
            }

            def pd [] {
              let input = $in
              if ($input | is-empty) { return }
              $input | to json | python3 ${pdScript}
            }
          '';
      };

      programs.carapace = {
        enable = true;
        enableNushellIntegration = true;
      };
    };
  };
}
