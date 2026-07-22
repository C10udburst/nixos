{
  description = "Nixos config flake";

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    nixosConfigurations."cloudburst-desktop" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/cloudburst-desktop/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        inputs.stylix.nixosModules.stylix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.cloudburst = {
            imports = [inputs.plasma-manager.homeModules.plasma-manager];
          };
        }
      ];
    };

    nixosConfigurations."cloudburst-laptop" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/cloudburst-laptop/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        inputs.stylix.nixosModules.stylix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.cloudburst = {
            imports = [inputs.plasma-manager.homeModules.plasma-manager];
          };
        }
      ];
    };
  };

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    peerix = {
      url = "github:cid-chan/peerix";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/5cb226a06c49f7a2d02863d0b5786a310599df6b";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    driftwm = {
      url = "github:malbiruk/driftwm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    driftwm-noctalia = {
      url = "github:youssefvdel/driftwm-noctalia";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi-agent.url = "github:lukasl-dev/pi.nix";
    antigravity-nix.url = "github:jacopone/antigravity-nix";

    scrcpy-app-src = {
      url = "github:C10udburst/scrcpy-app";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    organizeer = {
      url = "git+ssh://git@github.com/C10udburst/Organizeer.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── 3D tools & OpenSCAD libraries ────────────────────────────────────────
    orcaslicer-nanashi-appimage = {
      url = "https://github.com/NanashiTheNameless/OrcaSlicer/releases/download/Nightly-Rolling/OrcaSlicer_Linux_AppImage_Ubuntu2404_nightly.AppImage";
      flake = false;
    };

    # OpenSCAD libraries
    openscad-bosl2 = {
      url = "github:BelfrySCAD/BOSL2";
      flake = false;
    };
    openscad-constructive = {
      url = "git+https://codeberg.org/solidboredom/constructive";
      flake = false;
    };
    openscad-round-anything = {
      url = "github:Irev-Dev/Round-Anything";
      flake = false;
    };
    openscad-obiscad = {
      #https://github.com/Obijuan/obiscad/tree/master/obiscad
      url = "github:Obijuan/obiscad?dir=obiscad";
      flake = false;
    };

    # ── Ulauncher extensions ─────────────────────────────────────────────────
    ulauncher-homepage = {
      url = "github:pucodev/ulauncher-homepage";
      flake = false;
    };
    ulauncher-emoji = {
      url = "github:ulauncher/ulauncher-emoji";
      flake = false;
    };
    ulauncher-clipboard = {
      url = "github:friday/ulauncher-clipboard";
      flake = false;
    };
    ulauncher-system = {
      url = "github:iboyperson/ulauncher-system";
      flake = false;
    };
    ulauncher-bitwarden = {
      url = "github:kbialek/ulauncher-bitwarden";
      flake = false;
    };
    ulauncher-homeassistant = {
      url = "github:qcasey/ulauncher-homeassistant";
      flake = false;
    };
    ulauncher-unicode = {
      url = "github:zensoup/ulauncher-unicode";
      flake = false;
    };
    ulauncher-google-ai-mode = {
      url = "github:khurrambhutto/ulauncher-google-ai-mode";
      flake = false;
    };
    ulauncher-nix = {
      url = "github:daste745/ulauncher-nix";
      flake = false;
    };
  };
}
