# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "NixOS Dendritic Configuration";

  outputs = inputs: import ./outputs.nix inputs;

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    driftwm = {
      url = "github:malbiruk/driftwm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    driftwm-desktop = {
      url = "github:C10udburst/driftwm-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fetlife-browser = {
      url = "git+ssh://git@github.com/C10udburst/fetlife-browser.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file.url = "github:vic/flake-file";
    gitr = {
      url = "https://github.com/islandspan-solutions/gitr/releases/latest/download/gitr-x86_64.AppImage";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    isw = {
      url = "github:YoyPa/isw";
      flake = false;
    };
    jetbra-netfilter = {
      url = "https://ipfs.filebase.io/ipns/3.jetbra.in/files/jetbra-8f6785eac5e6e7e8b20e6174dd28bb19d8da7550.zip";
      flake = false;
    };
    kimsay = {
      url = "github:IcaroJam/kimsay";
      flake = false;
    };
    manyfold-printables = {
      url = "https://github.com/nxn94/manyfold_printables";
      flake = false;
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcache-oci = {
      url = "github:cmspam/nixcache-oci";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-cloudburst = {
      url = "github:C10udburst/noctalia-v5";
      flake = false;
    };
    noctalia-community-plugins = {
      url = "github:noctalia-dev/community-plugins";
      flake = false;
    };
    oci-lock = {
      url = "github:C10udburst/oci-lock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    openscad-bosl2 = {
      url = "github:BelfrySCAD/BOSL2";
      flake = false;
    };
    openscad-constructive = {
      url = "git+https://codeberg.org/solidboredom/constructive";
      flake = false;
    };
    openscad-obiscad = {
      url = "github:Obijuan/obiscad?dir=obiscad";
      flake = false;
    };
    openscad-round-anything = {
      url = "github:Irev-Dev/Round-Anything";
      flake = false;
    };
    organizeer.url = "git+ssh://git@github.com/C10udburst/Organizeer.git";
    pi-agent = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    ranger-archives = {
      url = "github:maximtrp/ranger-archives";
      flake = false;
    };
    ranger-devicons = {
      url = "github:alexanderjeurissen/ranger_devicons";
      flake = false;
    };
    scrcpy-app-src = {
      url = "github:C10udburst/scrcpy-app";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    shell-undo = {
      url = "github:edaywalid/undo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tailcat = {
      url = "github:tailscale/tailcat";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    webicons = {
      url = "github:C10udburst/webicons-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
