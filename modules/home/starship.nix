{
  config,
  lib,
  ...
}: {
  programs.bash.enable = true;
  programs.zsh.enable = true;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = "[](color_orange)$os$username[](bg:color_yellow fg:color_orange)$directory[](fg:color_yellow bg:color_aqua)$git_branch$git_status[](fg:color_aqua bg:color_blue)$c$rust$golang$nodejs[](fg:color_blue bg:color_bg3)$docker_context[](fg:color_bg3 bg:color_purple)$time[ ](fg:color_purple)\n$character";

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

      docker_context = {
        symbol = " ";
        style = "bg:color_bg3 fg:color_fg0";
        format = "[ $symbol ]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_purple fg:color_fg0";
        format = "[  $time ]($style)";
      };

      character = {
        success_symbol = "[➜](bold green) ";
        error_symbol = "[➜](bold red) ";
      };
    };
  };
}
