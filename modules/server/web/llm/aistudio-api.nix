{
  config,
  lib,
  pkgs,
  helpers,
  ...
}:
let
  cfg = config.features.server.web.llm.aistudioApi;
  storage = config.features.server.web.storage;
  webHelper = import ../_webService.nix { inherit config lib pkgs; };

  # AIStudioToAPI: exposes Google AI Studio Build apps as OpenAI/Gemini/Anthropic-compatible
  # APIs. Google accounts are added interactively through the web console (VNC login), so the
  # dashboard stays reachable; API access itself is guarded by API_KEYS. Sablier can suspend and
  # lazily wake it, which clients absorb by retrying while the proxy waits for the container.
  name = "aistudio-api";
  port = 7860;
in
{
  options.features.server.web.llm.aistudioApi = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.llm.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        inherit name port;
        suspend = "podman-${name}.service";
      })
      {
        users.users.${name} = {
          isSystemUser = true;
          group = name;
          home = "${storage}/${name}";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.${name} = { };

        # The app persists Google auth files in /app/configs/auth and request statistics in
        # /app/data (usage-stats.jsonl).
        systemd.tmpfiles.rules = [
          "d ${storage}/${name} 0751 ${name} web - -"
          "z ${storage}/${name} 0751 ${name} web - -"
          "d ${storage}/${name}/auth 0770 ${name} ${name} - -"
          "z ${storage}/${name}/auth 0770 ${name} ${name} - -"
          "d ${storage}/${name}/data 0770 ${name} ${name} - -"
          "z ${storage}/${name}/data 0770 ${name} ${name} - -"
        ];

        virtualisation.oci-containers.containers.${name} = {
          image = helpers.resolveImage "ghcr.io/ibuhub/aistudio-to-api:latest";
          podman.user = name;
          environment = {
            # Host networking together with the loopback bind: the reverse proxy on this host is
            # the only thing that can reach the gateway.
            HOST = "127.0.0.1";
            PORT = toString port;
            API_KEYS = "sk-1234";

            TZ = config.time.timeZone;
          };
          volumes = [
            "${storage}/${name}/auth:/app/configs/auth"
            "${storage}/${name}/data:/app/data"
          ];
          extraOptions = [ "--network=host" ];
        };
      }
    ]
  );
}
