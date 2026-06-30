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

      palette = "gruvbox";

      palettes.gruvbox = {
        color_fg0 = "#fbf1c7";
        color_bg0 = "#282828";
        color_bg1 = "#3c3836";
        color_bg3 = "#665c54";
        color_blue = "#458588";
        color_aqua = "#689d6a";
        color_green = "#b8bb26";
        color_orange = "#fe8019";
        color_purple = "#b16286";
        color_red = "#fb4934";
        color_yellow = "#fabd2f";
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
