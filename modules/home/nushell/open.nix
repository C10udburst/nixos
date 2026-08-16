{
  config,
  lib,
  ...
}: let
  cfg = config.homeSettings.nushell;

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
in {
  config = lib.mkIf cfg.enable {
    programs.nushell.extraConfig = nushellOpenOverride;
  };
}
