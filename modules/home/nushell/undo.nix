{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.homeSettings.nushell;
in {
  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optional config.homeSettings.shell-undo.enable
      inputs.shell-undo.packages.${pkgs.system}.default;

    programs.nushell.extraConfig = lib.optionalString config.homeSettings.shell-undo.enable ''
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
}
