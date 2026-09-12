{
  self,
  nixpkgs,
  ...
}@inputs:
let
  # Local copy only as fallback for when the import-tree module is not available
  importTree = inputs.import-tree or (import ./lib/import-tree.nix);
  dendriticModules = importTree ./modules;

  mkHost =
    {
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
            imports = [ inputs.plasma-manager.homeModules.plasma-manager ];
          };
        }
        dendriticModules
      ];
    };
in
{
  nixosConfigurations = {
    cloudburst-desktop = mkHost { hostName = "cloudburst-desktop"; };
    cloudburst-laptop = mkHost { hostName = "cloudburst-laptop"; };
    cloudburst-tablet = mkHost { hostName = "cloudburst-tablet"; };
    bootstrap = mkHost { hostName = "bootstrap"; };
  };
}
