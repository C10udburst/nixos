{
  features = {
    compat = {
      distrobox = false;
      enable = true;
      kvm = {
        enable = false;
      };
      podman = {
        dockerCompat = true;
        enable = false;
      };
      waydroid = false;
      wine = false;
    };
    core = {
      boot = {
        enable = true;
        grub32 = false;
        systemd = true;
        timeout = 2;
      };
      enable = true;
      hardware = {
        appimage = false;
        bluetooth = false;
        enable = true;
        fuse = true;
        ldfix = true;
        mobile = false;
        nvidia = false;
        pipewire = true;
        slow = false;
        touchscreen = false;
        vulnix = true;
        zram = true;
      };
      locale = {
        enable = true;
        pl = true;
      };
      nix = {
        autoOptimise = true;
        enable = true;
        flakes = true;
        gc = false;
      };
      users = {
        cloudburst = {
          admin = true;
          enable = true;
          extraGroups = ["podman"];
        };
        enable = true;
      };
    };
    gui = {
      apps = {
        brave = {
          apps = {
            enable = true;
            homelab = true;
            media = true;
            office = false;
            other = true;
            social = {
              core = true;
              web = false;
            };
          };
          enable = true;
          extraCliFlags = [];
          extraFlags = [];
        };
        editors = {
          enable = true;
          images = false;
          jetbrains = {
            enable = false;
          };
          office = {
            enable = true;
            libreoffice = false;
            pdf = true;
          };
          vscode = true;
        };
        enable = true;
        tools = {
          dolphin = true;
          enable = true;
          haruna = true;
          konsole = true;
          llm = {
            antigravity = true;
            enable = false;
            ollama = false;
            pi = true;
          };
          mayo = true;
          nomacs = true;
          obs = false;
          okular = true;
          social = {
            enable = false;
            signal = true;
            telegram = true;
            vesktop = true;
          };
        };
      };
      desktop = {
        driftwm = {
          desktop = true;
          enable = true;
          extraConfig = {};
          extracmds = [];
          noctalia = {
            enable = true;
            plugins = {
              connectivity = true;
              containers = true;
              core = true;
              enable = true;
              hardware = true;
              mobile = false;
              system = true;
            };
          };
        };
        enable = true;
        plasma = {
          enable = true;
          packages = true;
        };
      };
      dev = {
        android = {
          core = true;
          dev = false;
          enable = false;
          scrcpy = true;
        };
        arduino = {
          enable = false;
        };
        documents = {
          enable = true;
          latex = false;
          typst = false;
        };
        enable = false;
        programming = {
          enable = false;
          go = false;
          kotlin = false;
          node = false;
          rust = false;
        };
        python = {
          ai = false;
          dataScience = false;
          enable = true;
          utils = false;
        };
        threed = {
          blender = false;
          enable = false;
          freecad = false;
          openscad = {
            enable = false;
            libraries = true;
          };
          orca = false;
        };
      };
      enable = true;
      greeter = {
        enable = true;
        regreet = true;
      };
      theme = {
        enable = true;
        font = {
          enable = true;
        };
        polarity = "dark";
        wallpaper = {
          enable = true;
        };
      };
      xdg = {
        enable = true;
      };
    };
    server = {
      enable = false;
      samba = {
        enable = false;
        paths = [];
      };
      westonRdp = {
        enable = false;
        gskRenderer = "ngl";
        tlsCert = "/var/lib/weston-rdp/tls.crt";
        tlsKey = "/var/lib/weston-rdp/tls.key";
        user = "cloudburst";
        windowManager = "${pkgs.driftwm}/bin/driftwm";
      };
    };
    services = {
      enable = true;
      openssh = {
        enable = true;
        passwordAuthentication = true;
      };
      tailscale = {
        enable = true;
        exitNode = false;
      };
      usbip = false;
      waypipe = true;
      weylus = false;
    };
    shell = {
      enable = true;
      git = {
        enable = true;
        lfs = true;
      };
      nushell = {
        default = "term";
        enable = true;
        modules = true;
        scripts = true;
        undo = false;
        wrappers = true;
      };
      ranger = {
        enable = true;
      };
      scripts = {
        dev = true;
        documents = true;
        enable = true;
        hardware = true;
        media = true;
      };
      starship = {
        enable = true;
      };
      utils = {
        enable = true;
        fun = true;
        modernCli = true;
        nettools = true;
        nix = true;
      };
    };
  };
}
