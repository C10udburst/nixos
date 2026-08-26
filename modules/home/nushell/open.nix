{
  config,
  lib,
  ...
}: let
  cfg = config.homeSettings.nushell;

  openMap = {
    "^.*flake\\.nix$" = "nix eval --json --file $path_str inputs | from json";
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

    def --wrapped "open-custom" [path: any, ...rest] {
        let expanded = ($path | path expand)
        if ($rest | length) > 0 {
            return (nu-open $expanded ...$rest)
        }
        let path_str = ($expanded | into string)
        if ($expanded | path exists) {
            ${mkIfs (builtins.attrNames openMap)}
        }
        nu-open $expanded ...$rest
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
