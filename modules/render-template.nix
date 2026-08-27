{
  pkgs,
  config,
  lib,
}: let
  renderJinja2 = name: template: data:
    pkgs.runCommand name {
      nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.jinja2]))];
      jsonData = builtins.toJSON data;
      passAsFile = ["jsonData"];
    } ''
      python3 -c "
      import json
      from jinja2 import Template

      def to_rgb_vec3(hex_str):
          hex_str = hex_str.lstrip('#')
          r = int(hex_str[0:2], 16) / 255.0
          g = int(hex_str[2:4], 16) / 255.0
          b = int(hex_str[4:6], 16) / 255.0
          return f'vec3({r:.3f}, {g:.3f}, {b:.3f})'

      def hex2dec(hex_str):
          hex_str = hex_str.lstrip('#')
          r = int(hex_str[0:2], 16)
          g = int(hex_str[2:4], 16)
          b = int(hex_str[4:6], 16)
          return f'{r},{g},{b}'

      def hex2dec_space(hex_str):
          hex_str = hex_str.lstrip('#')
          r = int(hex_str[0:2], 16)
          g = int(hex_str[2:4], 16)
          b = int(hex_str[4:6], 16)
          return f'{r} {g} {b}'

      with open('$jsonDataPath') as f:
          data = json.load(f)

      with open('${template}') as f:
          tmpl = Template(f.read())

      tmpl.globals['to_rgb_vec3'] = to_rgb_vec3
      tmpl.globals['hex2dec'] = hex2dec
      tmpl.globals['hex2dec_space'] = hex2dec_space

      with open('$out', 'w') as f:
          f.write(tmpl.render(**data))
      "
    '';

  base16Keys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];
  cleanColors = lib.genAttrs base16Keys (key: config.lib.stylix.colors.${key});
in {
  inherit renderJinja2 cleanColors;
}
