{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.hostSettings.utils or false) {
    home.packages = with pkgs; [
      w3m
      archivemount
      ffmpegthumbnailer
      poppler-utils
      mediainfo
      exiftool
      atool
    ];

    programs.ranger = {
      enable = true;
      settings = {
        preview_images = true;
        preview_images_method = "kitty";
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
          src = pkgs.fetchFromGitHub {
            owner = "alexanderjeurissen";
            repo = "ranger_devicons";
            rev = "1bcaff0366a9d345313dc5af14002cfdcddabb82";
            sha256 = "1c01w16hbv6qjsa506m6wvhjy1qgalclq15qx67962xqahlsmxda";
          };
        }
        {
          name = "ranger-archives";
          src = pkgs.fetchFromGitHub {
            owner = "maximtrp";
            repo = "ranger-archives";
            rev = "0b1cfa9a77412c3b51da5b1b213c672227f9fbb4";
            sha256 = "1hzv3ykh94r6gd7px5d509j8yavgdn512sgmsb5f7ys6m7q7whhw";
          };
        }
      ];
    };

    xdg.configFile."ranger/scope.sh" = {
      source = ./scope.sh;
      executable = true;
    };

    xdg.configFile."ranger/commands.py" = {
      source = ./commands.py;
    };

    programs.bash.initExtra = ''
      # Automatically CD into the last open folder on Ranger close
      ranger() {
          local temp_file
          temp_file="$(mktemp -t "ranger_cd.XXXXXXXXXX")"
          command ranger --choosedir="$temp_file" -- "$@"
          if chosen_dir="$(cat -- "$temp_file")" && [ -n "$chosen_dir" ] && [ "$chosen_dir" != "$PWD" ]; then
              cd -- "$chosen_dir"
          fi
          rm -f -- "$temp_file"
      }
      # Bind Ctrl-O to run ranger
      bind '"\C-o":"ranger\C-m"'
    '';

    programs.zsh.initContent = ''
      # Automatically CD into the last open folder on Ranger close
      ranger() {
          local temp_file
          temp_file="$(mktemp -t "ranger_cd.XXXXXXXXXX")"
          command ranger --choosedir="$temp_file" -- "$@"
          if chosen_dir="$(cat -- "$temp_file")" && [ -n "$chosen_dir" ] && [ "$chosen_dir" != "$PWD" ]; then
              cd -- "$chosen_dir"
          fi
          rm -f -- "$temp_file"
      }
      # Bind Ctrl-O to run ranger
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
}
