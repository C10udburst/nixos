{
  config,
  lib,
  ...
}: {
  programs.bash.enable = true;
  programs.zsh.enable = true;
  home.sessionVariables.STARSHIP_LOG = "error";
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      scan_timeout = 120;
      add_newline = false;
      format = let
        segments = [
          {
            bg = "color_orange";
            content = "$os$username$hostname";
          }
          {
            bg = "color_yellow";
            content = "$directory";
          }
          {
            bg = "color_aqua";
            content = "$git_branch$git_status";
          }
          {
            bg = "color_blue";
            content = "$c$rust$golang$nodejs$gradle$python";
          }
          {
            bg = "color_bg3";
            content = "$docker_context";
          }
          {
            bg = "color_green";
            content = "$shlvl";
          }
          {
            bg = "color_purple";
            content = "$status$cmd_duration";
          }
        ];

        # Recursively join segments with transition arrows
        joinSegments = list:
          if list == []
          then ""
          else if builtins.length list == 1
          then (builtins.head list).content + "[ ](fg:${(builtins.head list).bg})\n$character"
          else let
            first = builtins.head list;
            rest = builtins.tail list;
            second = builtins.head rest;
          in
            first.content + "[](bg:${second.bg} fg:${first.bg})" + (joinSegments rest);

        firstBg = (builtins.head segments).bg;
      in
        "[](${firstBg})" + (joinSegments segments);

      palette = lib.mkForce "stylix";

      palettes.stylix = {
        color_fg0 = config.lib.stylix.colors.withHashtag.base05;
        color_bg0 = config.lib.stylix.colors.withHashtag.base00;
        color_bg1 = config.lib.stylix.colors.withHashtag.base01;
        color_bg3 = config.lib.stylix.colors.withHashtag.base03;
        color_blue = config.lib.stylix.colors.withHashtag.base0D;
        color_aqua = config.lib.stylix.colors.withHashtag.base0C;
        color_green = config.lib.stylix.colors.withHashtag.base0B;
        color_orange = config.lib.stylix.colors.withHashtag.base09;
        color_purple = config.lib.stylix.colors.withHashtag.base0E;
        color_red = config.lib.stylix.colors.withHashtag.base08;
        color_yellow = config.lib.stylix.colors.withHashtag.base0A;
      };

      os = {
        disabled = false;
        format = "[ $symbol]($style)";
        style = "bg:color_orange fg:color_fg0";
        symbols = {
          NixOS = " ";
        };
      };

      username = {
        show_always = true;
        style_user = "bg:color_orange fg:color_fg0";
        style_root = "bg:color_orange fg:color_fg0";
        format = "[ $user]($style)";
      };

      directory = {
        style = "bg:color_yellow fg:color_bg0";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      git_branch = {
        symbol = " ";
        style = "bg:color_aqua fg:color_bg0";
        format = "[ $symbol$branch ]($style)";
      };

      git_status = {
        style = "bg:color_aqua fg:color_bg0";
        format = "[[($all_status$ahead_behind )]($style)]($style)";
      };

      c = {
        symbol = " ";
        style = "bg:color_blue fg:color_bg0";
        format = "[ $symbol($version) ]($style)";
      };

      rust = {
        symbol = " ";
        style = "bg:color_blue fg:color_bg0";
        format = "[ $symbol($version) ]($style)";
      };

      golang = {
        symbol = " ";
        style = "bg:color_blue fg:color_bg0";
        format = "[ $symbol($version) ]($style)";
      };

      nodejs = {
        symbol = " ";
        style = "bg:color_blue fg:color_bg0";
        format = "[ $symbol($version) ]($style)";
      };

      gradle = {
        symbol = " ";
        style = "bg:color_blue fg:color_bg0";
        format = "[ $symbol($version) ]($style)";
      };

      docker_context = {
        symbol = " ";
        style = "bg:color_bg3 fg:color_fg0";
        format = "[ $symbol ]($style)";
      };

      shlvl = {
        disabled = false;
        threshold = 1;
        symbol = " ";
        style = "bg:color_green fg:color_bg0";
        format = "[ $symbol$shlvl ]($style)";
      };

      python = {
        symbol = " ";
        style = "bg:color_blue fg:color_bg0";
        format = "[ $symbol$version ]($style)[(\\($virtualenv\\)) ]($style)";
      };

      hostname = {
        ssh_only = true;
        disabled = false;
        ssh_symbol = "󰢹 ";
        style = "bg:color_orange fg:color_fg0";
        format = "[ $ssh_symbol$hostname ]($style)";
      };

      status = {
        disabled = false;
        symbol = "✗ ";
        style = "bg:color_purple fg:color_fg0";
        format = "[$symbol$status ]($style)";
      };

      cmd_duration = {
        disabled = false;
        min_time = 0;
        show_milliseconds = true;
        style = "bg:color_purple fg:color_fg0";
        format = "[ $duration ]($style)";
      };

      character = {
        success_symbol = "[\\$](bold green) ";
        error_symbol = "[\\$](bold red) ";
      };
    };
  };
}
