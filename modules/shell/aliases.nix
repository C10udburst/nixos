{
  config,
  lib,
  ...
}: let
  cfg = config.features.shell.aliases;
in {
  options.features.shell.aliases = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.enable && true;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst = {
      home.shellAliases =
        {
          ".." = "cd ..";
          "..." = "cd ../..";
          py = "python3";
          dc = "cd";
          cls = "printf '\\033[2J\\033[3J\\033[1;1H'";
          ll = "eza -la --sort name --group-directories-first --git --smart-group -h --extended --icons -M";
          l = "eza --icons --git --group-directories-first";
          tree = "eza --icons --git --group-directories-first -T -L 2";
          t = "eza --icons --git --group-directories-first -T -L 2";
          pubip = "dig +short myip.opendns.com @resolver1.opendns.com";
          "cd.." = "cd ..";
          "-" = "cd -";
        }
        // (lib.listToAttrs (
          map (i: {
            name = "..${toString i}";
            value = "cd " + (lib.concatStringsSep "/" (map (_x: "..") (lib.range 1 i)));
          }) (lib.range 2 10)
        ));
    };
  };
}
