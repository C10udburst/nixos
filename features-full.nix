{...}: {
  features = {
    core = {
      # Master switch for the core layer (default: true)
      enable = true;

      # Nix daemon & store settings (caches, trusted-users, gc schedule are handled globally)
      nix = {
        enable = true;
        flakes = true;
        autoOptimise = true;
        gc = false;
      };

      # Bootloader configuration
      boot = {
        enable = true;
        systemd = true; # systemd-boot for modern UEFI
        grub32 = false; # 32-bit GRUB2 for 32-bit UEFI tablets (e.g. Miix 300)
        timeout = 2;
      };

      # Locale and regional settings (all timezone, LC_*, consoleKeyMap are handled in pl.nix)
      locale = {
        pl = true; # Polish locale, timezone, and keymap
      };

      # Hardware profile flags & base driver toggles
      hardware = {
        enable = true;
        mobile = false; # Laptop / tablet power management
        touchscreen = false; # Auto-rotate, wvkbd on-screen keyboard
        slow = false; # Disables heavy animations, indexing, tesseract
        bluetooth = false; # Bluetooth disabled by default
        pipewire = true; # Audio daemon
        nvidia = false; # Proprietary Nvidia GPU driver stack
        zram = true; # Compressed swap on RAM
        ldfix = true; # nix-ld for unpatched binaries
        fuse = true; # FUSE filesystem support
        appimage = false; # AppImage runtime support (false by default)
        vulnix = true; # Vulnerability scanner (defaults to false if slow)
        nixIndex = true; # comma / nix-index database (defaults to false if slow)
      };

      # User account activation (shell, description, ssh keys are defined in cloudburst.nix)
      users = {
        cloudburst = {
          enable = true;
          admin = true;
          extraGroups = [
            # Host-specific groups (e.g. "podman" if containers active)
            "podman"
          ];
        };
      };
    };

    # Services but not explictly server-related
    services = {
      enable = true;
      tailscale = {
        enable = true;
        exitNode = false;
      };
      openssh = {
        enable = true;
        passwordAuthentication = true;
      };
      waypipe = true;
      weylus = false;
      usbip = false;
    };

    shell = {
      enable = true;

      # Nushell shell configuration
      nushell = {
        enable = true;
        default = "term"; # "none", "login", or "term" (default terminal shell)
        modules = true;
        wrappers = true;
        undo = false;
        scripts = true;
      };

      # Starship cross-shell prompt
      starship = {
        enable = true;
      };

      # Git version control (identity, email, defaultBranch are handled globally in git.nix)
      git = {
        enable = true;
        lfs = true;
      };

      # Ranger terminal file manager
      ranger = {
        enable = true;
        devicons = true;
        archives = true;
      };

      # Custom CLI utility scripts split into categories (from modules/shell/scripts/)
      scripts = {
        enable = true;
        media = true; # icat, palette, video8mb, chafa, libsixel, datauri
        dev = true; # gh-origin-mod, nix-py, nx, sarif-md
        hardware = true; # serial, extract, www, rofi, auto-rotate, weylus-screen
        documents = true; # beamer-clean, ics-merge, gcode-bounds
      };

      # Command-line utility packages split into categories
      utils = {
        enable = true;
        modernCli = true; # bat, fd, ripgrep, procs, dust, fzf, hexyl, binwalk, qrencode, zbar, jless
        fun = true; # kimsay, asciinema
        nettools = true; # nmap, traceroute, dig, mptcpd
      };
    };

    gui = {
      enable = true;

      # Theming engine (Stylix colors, JetBrainsMono font, and sizes handled globally)
      theme = {
        enable = true;
        core = {
          enable = true;
          polarity = "dark";
          base16Scheme = null; # null derives scheme dynamically from wallpaper
        };
        wallpaper = {
          enable = true;
          path = null; # defaults to co-located _wallpaper.jpg
        };
        font = {
          enable = true; # uses global JetBrainsMono Nerd Font setup
        };
      };

      # Display manager & greeter
      greeter = {
        greetd = {
          enable = true;
          autologin = false;
          defaultSession = "driftwm"; # by default pulls the first active desktop entry
        };
      };

      # Compositors & Desktop Environments
      desktop = {
        driftwm = {
          enable = true;
          extracmds = [];
          extraConfig = {}; # native Nix attribute set merged into config
          desktop = true; # enables driftwm-desktop (defaults to true unless slow)

          noctalia = {
            enable = true;
            plugins = {
              enable = true;
              core = true; # audio-switcher, cat, driftwm, driftwm-windows, unicode
              system = true; # procmon, screen-toolkit, hassio, cloudburst-nix
              hardware = true; # drive-health, udiskie (defaults to false if slow)
              mobile = false; # battery-threshold (defaults to true if mobile)
              connectivity = true; # phone-connect (defaults to false if slow), tailscale
              containers = true; # mini-docker (defaults to true if podman active)
            };
          };
        };

        plasma = {
          enable = true;
          packages = true; # extra KDE apps: Kate, KFind, Gwenview, etc.
        };
      };

      # Applications & Tools
      apps = {
        brave = {
          enable = true;
          extraFlags = []; # additional experimental browser flags
          extraCliFlags = []; # additional CLI flags (slow devices automatically receive low-resource flags)

          apps = {
            enable = true;
            office = false; # defaults to true if editors.office.libreoffice is false
            media = true; # Immich Photos, Fetlife DB
            homelab = true; # Home Assistant, Wealthfolio, SiYuan Notes
            social = {
              core = true; # web-only messengers without native clients (e.g. Messenger)
              web = false; # web versions of Discord/Telegram (disabled if native tools.social is true)
            };
          };
        };

        # Code & Document Editors
        editors = {
          office = {
            enable = true;
            libreoffice = false;
            pdf = true; # pdfgrep, pandoc, karp
          };
          vscode = true;
          jetbrains = {
            enable = false;
            # if enable = true, it only installs those IDEs that are set within
            # dev.programming.*.enable = true, e.g. dev.programming.rust.enable = true will install RustRover, kotlin will install IntelliJ, etc.
          };
        };

        # Native Desktop Tools & Utilities
        tools = {
          enable = true;
          dolphin = true;
          konsole = true;
          obs = false;
          social = {
            enable = false; # off by default, but if enable= true, it enabled submodules
            vesktop = true;
            telegram = true;
            signal = true;
          };

          llm = {
            enable = false;
            antigravity = true;
            pi = true;
            ollama = false;
          };
          associations = {
            enable = true;

            mayo = true;
            nomacs = true;
            haruna = true;
            okular = true;
            dolphin = true;
          };
        };
      };

      dev = {
        enable = false;

        programming = {
          enable = false;
          rust = false;
          go = false;
          node = false;
          kotlin = false;
        };

        python = {
          enable = true;
          dataScience = false; # numpy, pandas, scipy, matplotlib, scikit-learn, ipython
          ai = false; # PyTorch (CUDA-enabled if hardware.nvidia is on)
          utils = false; # requests, pypdf
        };

        arduino = {
          enable = false;
        };

        threed = {
          enable = false;
          blender = false;
          orca = false;
          freecad = false;
          openscad = {
            enable = false;
            libraries = true; # BOSL2, constructive, Round-Anything, obiscad
          };
        };

        documents = {
          latex = false;
          typst = false;
        };

        android = {
          enable = false;
          core = true; # adb, fastboot, udev rules
          scrcpy = true; # scrcpy screen mirroring
          dev = false; # Android Studio & SDK emulator
        };
      };
    };

    compat = {
      enable = true;
      wine = false;
      distrobox = false;
      waydroid = false;
      podman = {
        enable = false;
        dockerCompat = true;
      };

      kvm = {
        enable = false;
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
      };
    };
  };
}
