{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hassEnabled = config.features.server.web.homeassistant.enable;
  cfg = config.features.server.web.homeassistant.customComponents;

  pyPkgs = pkgs.home-assistant.python3Packages;

  resolveDep = req: let
    name = builtins.head (builtins.split "[><=!; ]" req);
    kebab = builtins.replaceStrings ["_" "."] ["-" "-"] name;
    snake = builtins.replaceStrings ["-"] ["_"] kebab;
  in
    pyPkgs.${name} or pyPkgs.${kebab} or pyPkgs.${snake} or null;

  mkComponent = src: let
    ccDir = src + "/custom_components";
    dirs =
      if builtins.pathExists ccDir
      then builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ccDir))
      else [];
    manifestPath =
      if builtins.pathExists (src + "/manifest.json")
      then src + "/manifest.json"
      else if dirs != []
      then src + "/custom_components/${builtins.head dirs}/manifest.json"
      else throw "Could not find manifest.json in source ${toString src}";

    manifest = builtins.fromJSON (builtins.readFile manifestPath);
    actualVersion =
      if manifest ? version && manifest.version != null
      then lib.removePrefix "v" manifest.version
      else "0.0.0";
    actualOwner =
      if manifest ? codeowners && manifest.codeowners != []
      then lib.removePrefix "@" (builtins.head manifest.codeowners)
      else "home-assistant";
    requirements = manifest.requirements or [];
    resolvedDeps = builtins.filter (x: x != null) (map resolveDep requirements);
  in
    pkgs.buildHomeAssistantComponent {
      inherit src;
      owner = actualOwner;
      version = actualVersion;
      domain = manifest.domain;
      dontCheckManifest = false;
      dependencies = resolvedDeps;
    };

  componentInputs = builtins.filter (input: input != null) [
    (inputs.hass-adaptive-lighting or null)
    (inputs.hass-burze-dzis-net or null)
    (inputs.hass-magic-areas or null)
    (inputs.hass-xiaomi-home or null)
    (inputs.hass-bermuda or null)
    (inputs.hass-energy-hub-poland or null)
    (inputs.hass-illuminance or null)
    (inputs.hass-moonraker or null)
    (inputs.hass-waste-collection-schedule or null)
    (inputs.hass-xiaomi-miot or null)
    (inputs.hass-bodymiscale or null)
    (inputs.hass-powercalc or null)
  ];
in {
  options.features.server.web.homeassistant.customComponents = lib.mkOption {
    type = lib.types.bool;
    default = hassEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        hass-adaptive-lighting = {
          url = "github:basnijholt/adaptive-lighting";
          flake = false;
        };
        hass-burze-dzis-net = {
          url = "github:PiotrMachowski/Home-Assistant-custom-components-Burze.dzis.net";
          flake = false;
        };
        hass-magic-areas = {
          url = "github:jseidl/hass-magic_areas";
          flake = false;
        };
        hass-xiaomi-home = {
          url = "github:XiaoMi/ha_xiaomi_home";
          flake = false;
        };
        hass-bermuda = {
          url = "github:agittins/bermuda";
          flake = false;
        };
        hass-energy-hub-poland = {
          url = "github:AllonGit/energy_hub_poland";
          flake = false;
        };
        hass-illuminance = {
          url = "github:pnbruckner/ha-illuminance";
          flake = false;
        };
        hass-moonraker = {
          url = "github:marcolivierarsenault/moonraker-home-assistant";
          flake = false;
        };
        hass-waste-collection-schedule = {
          url = "github:mampfes/hacs_waste_collection_schedule";
          flake = false;
        };
        hass-xiaomi-miot = {
          url = "github:al-one/hass-xiaomi-miot";
          flake = false;
        };
        hass-bodymiscale = {
          url = "github:dckiller51/bodymiscale";
          flake = false;
        };
        hass-powercalc = {
          url = "github:bramstroker/homeassistant-powercalc";
          flake = false;
        };
      };
    }
    (lib.mkIf (hassEnabled && cfg) {
      services.home-assistant.customComponents = map mkComponent componentInputs;
    })
  ];
}
