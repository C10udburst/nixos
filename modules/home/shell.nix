{
  config,
  lib,
  ...
}: let
  cfg = config.homeSettings.shell;
in {
  options.homeSettings.shell = {
    enable = lib.mkEnableOption "Enable shell aliases";
  };

  config = lib.mkIf cfg.enable {
    home.shellAliases =
      {
        ".." = "cd ..";
        "..." = "cd ../..";
        py = "python3";
        dc = "cd";
        cls = "printf '\033[2J\033[3J\033[1;1H'";
        ll = "eza -la --sort name --group-directories-first --git --smart-group -h --extended --icons -M";
        l = "eza --icons --git --group-directories-first";
        tree = "eza --icons --git --group-directories-first -T -L 2";
        t = "eza --icons --git --group-directories-first -T -L 2";
        # "top-10" = "history | awk '{CMD[\$2]++;count++;}END { for (a in CMD)print CMD[a] \" \" CMD[a]/count*100 \"% \" a;}' | grep -v \"./\" | column -c3 -s \" \" -t | sort -nr | nl |  head -n10";
        # "top-n" = "history | awk '{CMD[\$2]++;count++;}END { for (a in CMD)print CMD[a] \" \" CMD[a]/count*100 \"% \" a;}' | grep -v \"./\" | column -c3 -s \" \" -t | sort -nr | nl |  head -n ";
        # lsport = "sudo lsof -i -P -n | grep --color=never LISTEN";
        pubip = "dig +short myip.opendns.com @resolver1.opendns.com";
        # localip = "ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'";
        # ips = "ifconfig -a | grep -o 'inet6\\? \\(addr:\\)\\?\\s\\?\\(\\(\\([0-9]\\+\\.\\)\\{3\\}[0-9]\\+\\)\\|[a-fA-F0-9:]\\+\\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'";
        # pause = "printf \"Press any key to continue...\"; read -s -n 1; printf \"\\n\"";
        "cd.." = "cd ..";
        "-" = "cd -";
        icat = "kitty +kitten icat";
      }
      // (lib.listToAttrs (
        map (i: {
          name = "..${toString i}";
          value = "cd " + (lib.concatStringsSep "/" (map (x: "..") (lib.range 1 i)));
        }) (lib.range 2 10)
      ));
  };
}
