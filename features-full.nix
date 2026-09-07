{
  features = {
    compat = {
      appimage = false;
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
        bluetooth = true;
        ddc = false;
        enable = true;
        fuse = true;
        mobile = false;
        nix-ld = true;
        nvidia = false;
        pipewire = true;
        slow = false;
        touchscreen = false;
        zram = true;
      };
      java = {
        enable = true;
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
        vulnix = true;
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
          jetbrains = {
            enable = false;
          };
          media = {
            audio = true;
            enable = false;
            images = true;
            videos = true;
          };
          office = {
            enable = true;
            libreoffice = false;
            pdf = true;
          };
          vscode = true;
        };
        enable = true;
        threed = {
          blender = true;
          enable = false;
          freecad = true;
          openscad = {
            enable = true;
            libraries = true;
          };
          orca = true;
        };
        tools = {
          calc = true;
          enable = true;
          hardinfo = true;
          konsole = true;
          llm = {
            antigravity = true;
            enable = false;
            ollama = false;
            pi = true;
          };
          net = {
            enable = false;
          };
          obs = false;
          organizeer = true;
          social = {
            enable = false;
            signal = true;
            telegram = true;
            vesktop = true;
          };
        };
        viewers = {
          dolphin = true;
          enable = true;
          haruna = true;
          mayo = true;
          nomacs = true;
          okular = true;
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
          enable = true;
          go = false;
          kotlin = false;
          misc = true;
          node = false;
          rust = false;
        };
        python = {
          ai = false;
          dataScience = false;
          enable = true;
          utils = false;
        };
      };
      enable = true;
      games = {
        enable = false;
        epic = false;
        misc = false;
        steam = false;
      };
      greeter = {
        enable = true;
        regreet = true;
      };
      shell = {
        enable = true;
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
      tools = {
        net = {
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
        desktop = "driftwm";
        enable = false;
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
      aliases = {
        enable = true;
      };
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
        archive = true;
        core = true;
        diagnostics = true;
        enable = true;
        fun = true;
        media = true;
        modern = true;
        nettools = true;
        nix = true;
      };
    };
  };
}
