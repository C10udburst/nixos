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

  openMap = {
    "^.*flake\\.nix$" = "nix eval --json --file $path inputs | from json";
  };

  nushellOpenOverride = let
    mkIfs = patterns: let
      pattern = builtins.head patterns;
      cmd = openMap.${pattern};
      rest = builtins.tail patterns;
    in
      if patterns == []
      then ""
      else ''
        if ($path_str =~ '${pattern}') {
                    return (${cmd})
                }
                ${mkIfs rest}
      '';
  in ''
    alias nu-open = open

    def "open-custom" [path: any, ...rest] {
        let path_str = ($path | into string)
        if ($path | path exists) {
            ${mkIfs (builtins.attrNames openMap)}
        }
        nu-open $path ...$rest
    }

    def --wrapped open [path?: any, ...rest] {
        let input = $in
        if $path == null {
            if ($input | describe) == "string" {
                open-custom $input ...$rest
            } else {
                $input | nu-open ...$rest
            }
        } else {
            open-custom $path ...$rest
        }
    }
  '';

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
        + nushellOpenOverride
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

              let dir = ($env.UNDO_DATA_DIR? | default $"($env.HOME)/.local/share/undo" | path join "sessions" (date now | into int | into string))
              mkdir -p $"($dir)/data"
              $cmd | save -f $"($dir)/cmd"
              $nu.pid | save -f $"($dir)/pid"

              let old_preload = $env.LD_PRELOAD? | default ""
              let preloads = ($old_preload | split row ":" | where { not ($in | str ends-with "libundo.so") and ($in != "") })

              load-env {
                  UNDO_SESSION: $dir
                  _undo_session: $dir
                  _undo_saved_preload: $old_preload
                  LD_PRELOAD: ([$undo_lib] | append $preloads | str join ":")
                  UNDO_HOOK: "nushell"
              }
          })

          $env.config.hooks = ($env.config.hooks | default [] pre_prompt)
          $env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt | append {||
              if not ("_undo_session" in $env) { return }
              let dir = $env._undo_session

              if $env._undo_saved_preload == "" { hide-env LD_PRELOAD } else { load-env { LD_PRELOAD: $env._undo_saved_preload } }
              hide-env UNDO_SESSION _undo_session _undo_saved_preload

              "" | save -f $"($dir)/done"
              do -i { undo gc --auto }
          })
        '';
    };

    # Enable Starship integration
    programs.starship.enableNushellIntegration = true;
  };
}
