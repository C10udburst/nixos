{
  description = "NixOS Dendritic Configuration";

  flake-file.outputs = "inputs: import ./outputs.nix inputs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    import-tree.url = "github:denful/import-tree";
    flake-file.url = "github:vic/flake-file";

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

    driftwm-desktop = {
      url = "github:C10udburst/driftwm-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-community-plugins = {
      url = "github:noctalia-dev/community-plugins";
      flake = false;
    };

    noctalia-cloudburst = {
      url = "github:C10udburst/noctalia-v5";
      flake = false;
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi-agent.url = "github:lukasl-dev/pi.nix";
    antigravity-nix.url = "github:jacopone/antigravity-nix";

    shell-undo = {
      url = "github:edaywalid/undo";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    scrcpy-app-src = {
      url = "github:C10udburst/scrcpy-app";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    organizeer = {
      url = "git+ssh://git@github.com/C10udburst/Organizeer.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gitr = {
      url = "https://github.com/islandspan-solutions/gitr/releases/latest/download/gitr-x86_64.AppImage";
      flake = false;
    };

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
      url = "github:Obijuan/obiscad?dir=obiscad";
      flake = false;
    };

    ranger-devicons = {
      url = "github:alexanderjeurissen/ranger_devicons";
      flake = false;
    };

    ranger-archives = {
      url = "github:maximtrp/ranger-archives";
      flake = false;
    };

    isw = {
      url = "github:YoyPa/isw";
      flake = false;
    };

    tailcat = {
      url = "github:tailscale/tailcat";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    webicons = {
      url = "github:C10udburst/webicons-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    kimsay = {
      url = "github:IcaroJam/kimsay";
      flake = false;
    };
  };
}
