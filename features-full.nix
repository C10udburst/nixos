{
  features = {
    compat = {
      appimage = false;
      distrobox = true;
      enable = true;
      kvm = {
        enable = false;
      };
      nix-alien = true;
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
      firewall = false;
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
        ssd = {
          btrfsAutoScrub = true;
          enable = true;
          fstrim = true;
          smartd = true;
          tools = true;
        };
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
        gc = false;
        vulnix = true;
      };
      users = {
        cloudburst = {
          admin = true;
          enable = true;
          extraGroups = [];
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
            enable = true;
            images = true;
            videos = true;
          };
          office = {
            enable = true;
            libreoffice = true;
            pdf = true;
          };
          vscode = true;
        };
        enable = true;
        threed = {
          blender = true;
          enable = true;
          freecad = true;
          openscad = {
            enable = true;
            libraries = true;
          };
          orca = true;
        };
        tools = {
          enable = true;
          hardinfo = true;
          konsole = true;
          llm = {
            antigravity = true;
            enable = true;
            ollama = false;
            pi = true;
          };
          net = {
            enable = true;
          };
          obs = true;
          organizeer = true;
          qalculate = true;
          social = {
            enable = true;
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
          keyring = {
            enable = true;
          };
          packages = true;
        };
      };
      dev = {
        android = {
          core = true;
          dev = false;
          enable = true;
          jadx = false;
          scrcpy = true;
        };
        arduino = {
          enable = false;
        };
        documents = {
          enable = true;
          latex = true;
          typst = true;
        };
        enable = false;
        programming = {
          enable = true;
          go = true;
          kotlin = true;
          misc = true;
          node = true;
          rust = true;
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
        editors = {
          enable = true;
        };
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
      web = {
        copyparty = {
          enable = false;
        };
        core = {
          _apps = [];
          baseDomain = "brix0.wilkins.pl.eu.org";
          enable = false;
        };
        enable = false;
        gitea = {};
        golink = {
          enable = false;
          hostGo = true;
        };
        homarr = {
          enable = false;
        };
        homeassistant = {
          enable = false;
          esphome = false;
        };
        homepage = {
          enable = false;
        };
        immich = {
          enable = false;
          ml = "openvino";
        };
        karakeep = {};
        manyfold = {};
        pihole = {
          coredns = {};
          dnsServers = ["192.168.1.10" "192.168.1.11" "192.168.1.1"];
          enable = false;
        };
        redirect = {};
        sablier = {};
        siyuan = {
          enable = false;
        };
        ssl = {
          enable = false;
        };
        storage = "/opt";
        tailscale = {};
        transmute = {
          enable = false;
        };
        vaultwarden = {
          enable = false;
        };
        wealthfolio = {
          enable = false;
        };
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
