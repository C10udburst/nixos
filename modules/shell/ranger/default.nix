{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.ranger;
in {
  options.features.shell.ranger = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.shell.enable
        then true
        else false;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        ranger-devicons = {
          url = "github:alexanderjeurissen/ranger_devicons";
          flake = false;
        };
        ranger-archives = {
          url = "github:maximtrp/ranger-archives";
          flake = false;
        };
      };
    }
    (lib.mkIf (config.features.shell.enable && cfg.enable) {
      environment.systemPackages = [pkgs.ranger];

      home-manager.users.cloudburst = {
        home.packages = with pkgs; [
          w3m
          archivemount
          ffmpegthumbnailer
          poppler-utils
          mediainfo
          exiftool
          atool
          chafa
          libsixel
        ];

        programs.ranger = {
          enable = true;
          settings = {
            preview_images = true;
            preview_images_method = "sixel";
            vcs_aware = true;
            use_preview_script = true;
            preview_script = "~/.config/ranger/scope.sh";
          };
          extraConfig = ''
            default_linemode devicons
            map xb binwalk_extract
          '';
          plugins = [
            {
              name = "ranger_devicons";
              src = inputs.ranger-devicons;
            }
            {
              name = "ranger-archives";
              src = inputs.ranger-archives;
            }
          ];
        };

        xdg.configFile."ranger/scope.sh" = {
          source = ./_scope.sh;
          executable = true;
        };

        xdg.configFile."ranger/commands.py" = {
          source = ./_commands.py;
        };

        programs.bash.initExtra = ''
          ranger() {
              local temp_file
              temp_file="$(mktemp -t "ranger_cd.XXXXXXXXXX")"
              command ranger --choosedir="$temp_file" -- "$@"
              if chosen_dir="$(cat -- "$temp_file")" && [ -n "$chosen_dir" ] && [ "$chosen_dir" != "$PWD" ]; then
                  cd -- "$chosen_dir"
              fi
              rm -f -- "$temp_file"
          }
          bind '"\C-o":"ranger\C-m"'
        '';

        programs.zsh.initContent = ''
          ranger() {
              local temp_file
              temp_file="$(mktemp -t "ranger_cd.XXXXXXXXXX")"
              command ranger --choosedir="$temp_file" -- "$@"
              if chosen_dir="$(cat -- "$temp_file")" && [ -n "$chosen_dir" ] && [ "$chosen_dir" != "$PWD" ]; then
                  cd -- "$chosen_dir"
              fi
              rm -f -- "$temp_file"
          }
          ranger-cd-widget() {
              ranger
              zle reset-prompt
          }
          zle -N ranger-cd-widget
          bindkey '^O' ranger-cd-widget
        '';

        programs.nushell.extraConfig = ''
          def --env ranger [...args] {
              let tmp = ($nu.home-dir | path join ".ranger_nushell_dir")
              if ($tmp | path exists) { rm -f $tmp }
              if ($args | is-empty) {
                  ^ranger --choosedir=$"($tmp)"
              } else {
                  ^ranger --choosedir=$"($tmp)" ...$args
              }
              if ($tmp | path exists) {
                  let target = (open --raw $tmp | decode utf-8 | str trim)
                  rm -f $tmp

                  if ($target != "" and $target != $env.PWD) {
                      cd $target
                  }
              }
          }
          $env.config.keybindings = ($env.config.keybindings | append {
              name: open_ranger
              modifier: control
              keycode: char_o
              mode: [emacs, vi_insert, vi_normal]
              event: [{ send: executehostcommand, cmd: "ranger" }]
          })
        '';
      };
    })
  ];
}
