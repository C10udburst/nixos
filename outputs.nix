{
  self,
  nixpkgs,
  ...
} @ inputs: let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  forEachSystem = nixpkgs.lib.genAttrs systems;
  importTree = inputs.import-tree or (import ./lib/import-tree.nix);
  dendriticModules = importTree ./modules;

  mkHost = {
    hostName,
    system ? "x86_64-linux",
  }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs self;
      };
      modules = [
        ./hosts/${hostName}/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        inputs.stylix.nixosModules.stylix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.cloudburst = {
            imports = [inputs.plasma-manager.homeModules.plasma-manager];
          };
        }
        dendriticModules
      ];
    };
in {
  devShells = forEachSystem (system: {
    default = nixpkgs.legacyPackages.${system}.mkShell {
      packages = [inputs.driftwm-desktop.packages.${system}.default];
    };
    driftwm-desktop = nixpkgs.legacyPackages.${system}.mkShell {
      packages = [inputs.driftwm-desktop.packages.${system}.default];
    };
  });

  packages = forEachSystem (system: {
    default = inputs.driftwm-desktop.packages.${system}.default;
    driftwm-desktop = inputs.driftwm-desktop.packages.${system}.default;
  });

  nixosConfigurations = {
    cloudburst-desktop = mkHost {hostName = "cloudburst-desktop";};
    cloudburst-laptop = mkHost {hostName = "cloudburst-laptop";};
    cloudburst-tablet = mkHost {hostName = "cloudburst-tablet";};
    bootstrap = mkHost {hostName = "bootstrap";};
  };
}
