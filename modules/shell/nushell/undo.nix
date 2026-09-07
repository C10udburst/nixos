{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.nushell;
in {
  options.features.shell.nushell.undo = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.shell.enable && config.features.shell.nushell.enable) && false;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        shell-undo = {
          url = "github:edaywalid/undo";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.undo {
      home-manager.users.cloudburst = {
        home.packages = [
          inputs.shell-undo.packages.${pkgs.system}.default
        ];

        programs.nushell.extraConfig = ''
          let undo_lib = "${inputs.shell-undo.packages.${pkgs.system}.default}/lib/undo/libundo.so"

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
              let ignored_prefixes = ["undo" "distrobox" "podman" "docker" "flatpak"]
              if ($cmd | is-empty) or ($ignored_prefixes | any {|p| $cmd | str starts-with $p }) { return }

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

              if "LD_PRELOAD" in $env {
                  let remaining = ($env.LD_PRELOAD | split row ":" | where { not ($in | str ends-with "libundo.so") and ($in != "") })
                  if ($remaining | is-empty) {
                      hide-env LD_PRELOAD
                  } else {
                      load-env { LD_PRELOAD: ($remaining | str join ":") }
                  }
              }
              hide-env UNDO_SESSION _undo_session _undo_saved_preload

              "" | save -f $"($dir)/done"
              do -i { undo gc --auto }
          })
        '';
      };
    })
  ];
}
