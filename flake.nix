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
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    peerix = {
      url = "github:cid-chan/peerix";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/5cb226a06c49f7a2d02863d0b5786a310599df6b";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi-agent.url = "github:lukasl-dev/pi-mono.nix";
    antigravity-nix.url = "github:jacopone/antigravity-nix";

    orcaslicer-nanashi-appimage = {
      url = "https://github.com/NanashiTheNameless/OrcaSlicer/releases/download/Nightly-Rolling/OrcaSlicer_Linux_AppImage_Ubuntu2404_nightly.AppImage";
      flake = false;
    };

    # Ulauncher Extensions
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
