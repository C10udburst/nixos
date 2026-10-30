_: {
  features = {
    core = {
      java = false;
      boot = {
        systemd = false;
        grub = true;
      };
      hardware = {
        mobile = true;
        touchscreen = true;
        slow = true;
        eco = true;
      };
      nix = {
        vulnix = false;
        ghcr = false;
      };
    };

    gui = {
      desktop.driftwm.extracmds = [
        "wlr-randr --output eDP-1 --scale 1.5"
      ];
      apps = {
        editors.enable = false;
        threed.enable = false;
        tools = {
          obs = false;
          net = false;
          organizeer = false;
          social = {
            vesktop = false;
            signal = false;
          };
          llm = {
            pi.useNodeRuntime = true;
            pi.organizeer = true;
            antigravity = false;
          };
        };
      };
      dev = {
        android.enable = true;
        python = {
          enable = true;
          dataScience = false;
          ai = false;
        };
      };
    };

    compat = {
      enable = false;
    };
  };
}
