{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.homeSettings.driftwm;
  driftwmPkg = pkgs.driftwm or (throw "driftwm package not found");

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

      with open('$jsonDataPath') as f:
          data = json.load(f)

      with open('${template}') as f:
          tmpl = Template(f.read())

      tmpl.globals['to_rgb_vec3'] = to_rgb_vec3

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

  templateData =
    cleanColors
    // {
      font = config.stylix.fonts.monospace.name or "JetBrainsMono Nerd Font";
    };

  renderedConfig = renderJinja2 "config.toml" ./config.toml.j2 templateData;
  renderedShader = renderJinja2 "background.glsl" ./background.glsl.j2 templateData;
in {
  options.homeSettings.driftwm = {
    enable = mkEnableOption "driftwm";
  };

  config = mkIf cfg.enable {
    home.packages = [
      driftwmPkg
      pkgs.wlr-randr
      pkgs.playerctl
      pkgs.pavucontrol
      pkgs.pamixer
      pkgs.kdePackages.dolphin

      # Qt / SVG icon support
      pkgs.libsForQt5.qtsvg
      pkgs.kdePackages.qtsvg
      pkgs.libsForQt5.qt5ct
      pkgs.kdePackages.qt6ct
    ];

    programs.kitty.enable = true;

    xdg.configFile = {
      "qt5ct/qt5ct.conf".text = ''
        [Appearance]
        icon_theme=breeze-dark
      '';
      "qt6ct/qt6ct.conf".text = ''
        [Appearance]
        icon_theme=breeze-dark
      '';
    };

    programs.noctalia-shell = {
      enable = true;
      settings = mkForce ./noctalia.json;
    };

    systemd.user.services.driftwm = {
      Unit = {
        Description = "driftwm compositor";
        BindsTo = "graphical-session.target";
        Before = "graphical-session.target";
        Wants = "graphical-session-pre.target";
        After = "graphical-session-pre.target";
      };
      Service = {
        Slice = "session.slice";
        Type = "notify";
        NotifyAccess = "main";
        UnsetEnvironment = "WAYLAND_DISPLAY DISPLAY WAYLAND_SOCKET";
        Environment = "XKB_DEFAULT_LAYOUT=pl";
        ExecStart = "${driftwmPkg}/bin/driftwm --backend udev";
      };
    };

    systemd.user.services.pam-kwallet-init = {
      Unit = {
        Description = "Unlock kwallet from pam credentials";
        PartOf = ["graphical-session.target"];
        After = ["driftwm.service"];
        Requisite = ["driftwm.service"];
      };
      Service = {
        ExecStart = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";
        Type = "simple";
        Restart = "no";
      };
      Install = {
        WantedBy = ["driftwm.service"];
      };
    };

    xdg.configFile."driftwm/background.glsl".source = renderedShader;
    xdg.configFile."driftwm/config.toml".source = renderedConfig;
  };
}
