{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.homeSettings.nushell;

  plotScript = pkgs.writeText "plot.py" (builtins.readFile ./plot.py);
  pdScript = pkgs.writeText "pd.py" (builtins.readFile ./pd.py);

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
    home.packages =
      lib.optional config.homeSettings.shell-undo.enable
      inputs.shell-undo.packages.${pkgs.system}.default;

    programs.nushell = {
      enable = true;
      package = pkgs.nushell;
      extraConfig =
        (lib.concatStringsSep "\n" (
          map (module: "use ${pkgs.nu_scripts}/share/nu_scripts/${module} *") modules
        ))
        + "\n"
        + ''
          $env.config.show_banner = false
          # col_x / col_y accept either a column name (string) or a closure
          # that maps each row to a scalar value, e.g.: plot {$in.mem / $in.virtual}
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
              $x_vals | wrap $x_label | to json | python3 ${plotScript} $x_label
            } else {
              let y_label = if ($col_y | describe) == "closure" { "y" } else { $col_y }
              let y_vals = if ($col_y | describe) == "closure" {
                $data | each { |row| $row | do $col_y }
              } else {
                $data | get $col_y
              }
              $x_vals | wrap $x_label | merge ($y_vals | wrap $y_label) | to json | python3 ${plotScript} $x_label $y_label
            }
          }
          # Run a pandas transformation on the piped table.
          # `df` (DataFrame) and `pd` (pandas module) are pre-bound.
          # Mutate `df` in-place or assign to `result` for the output value.
          # Use --columns (-c) to select specific columns from the resulting DataFrame.
          #
          # Examples:
          #   ps | pd "df['mb'] = df.mem / 1024**2"
          #   open data.csv | pd "df = df.groupby('host').sum().reset_index()" --columns [host bytes]
          #   open data.csv | pd "result = df.describe()"
          def pd [
            script: string,
            --columns (-c): list<string> = []
          ] {
            let data = $in
            if ($columns | is-empty) {
              $data | to json | python3 ${pdScript} $script | from json
            } else {
              $data | to json | python3 ${pdScript} $script ...$columns | from json
            }
          }
        ''
        + lib.optionalString config.homeSettings.shell-undo.enable ''
          # Custom hook for shell-undo
          let undo_lib = "${inputs.shell-undo.packages.${pkgs.system}.default}/lib/undo/libundo.so"

          # Override built-ins with external commands so LD_PRELOAD applies
          alias rm = ^rm
          alias cp = ^cp
          alias mv = ^mv
          alias touch = ^touch
          alias mkdir = ^mkdir
          alias mktemp = ^mktemp

          $env.config = ($env.config | default {} hooks)
          $env.config.hooks = ($env.config.hooks | default [] pre_execution)
          $env.config.hooks.pre_execution = ($env.config.hooks.pre_execution | append {||
              let cmd = (commandline | str trim)
              if ($cmd | is-empty) or ($cmd | str starts-with "undo") { return }

              let xdg_data = (if "XDG_DATA_HOME" in $env { $env.XDG_DATA_HOME } else { $"($env.HOME)/.local/share" })
              let data_dir = (if "UNDO_DATA_DIR" in $env { $env.UNDO_DATA_DIR } else { $"($xdg_data)/undo" })
              let sessions_dir = $"($data_dir)/sessions"

              # Ensure directories exist
              mkdir $sessions_dir

              # Generate session ID using nanoseconds timestamp
              let id = (date now | into int | into string)
              let dir = $"($sessions_dir)/($id)"
              mkdir $"($dir)/data"

              $cmd | save -f $"($dir)/cmd"
              $nu.pid | save -f $"($dir)/pid"

              # Save current LD_PRELOAD
              let old_preload = (if "LD_PRELOAD" in $env { $env.LD_PRELOAD } else { "__undo_unset__" })

              # Clean other libundo.so from LD_PRELOAD if exists
              let preloads = (if $old_preload == "__undo_unset__" or $old_preload == "" {
                  []
              } else {
                  $old_preload | split row ":" | where { |x| not ($x | str ends-with "libundo.so") }
              })

              let new_preload = ([$undo_lib] | append $preloads | str join ":")

              load-env {
                  UNDO_SESSION: $dir
                  _undo_session: $dir
                  _undo_saved_preload: $old_preload
                  LD_PRELOAD: $new_preload
                  UNDO_HOOK: "nushell"
              }
          })

          $env.config.hooks = ($env.config.hooks | default [] pre_prompt)
          $env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt | append {||
              if not ("_undo_session" in $env) { return }
              let dir = $env._undo_session

              # Restore LD_PRELOAD
              let saved_preload = $env._undo_saved_preload
              if $saved_preload == "__undo_unset__" or $saved_preload == "" {
                  hide-env LD_PRELOAD
              } else {
                  load-env { LD_PRELOAD: $saved_preload }
              }

              hide-env UNDO_SESSION
              hide-env _undo_session
              hide-env _undo_saved_preload

              # Mark session as done
              "" | save -f $"($dir)/done"

              # Prune
              if (which undo | is-empty) {
                  # Fallback manual prune
                  let undo_keep = (if "UNDO_KEEP" in $env { $env.UNDO_KEEP | into int } else { 30 })
                  let xdg_data = (if "XDG_DATA_HOME" in $env { $env.XDG_DATA_HOME } else { $"($env.HOME)/.local/share" })
                  let data_dir = (if "UNDO_DATA_DIR" in $env { $env.UNDO_DATA_DIR } else { $"($xdg_data)/undo" })
                  let sessions_dir = $"($data_dir)/sessions"

                  let sessions = (ls $sessions_dir | sort-by name | reverse)
                  if ($sessions | length) > $undo_keep {
                      $sessions | skip $undo_keep | each { |s| rm -rf $s.name }
                  }
              } else {
                  # Run undo gc --auto in background/silent
                  do -i { undo gc --auto }
              }
          })
        '';
    };

    # Enable Starship integration
    programs.starship.enableNushellIntegration = true;
  };
}
