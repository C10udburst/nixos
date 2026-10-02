{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.metube;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  presets = {
    sponsorblock = {
      postprocessors = [
        {
          key = "SponsorBlock";
          categories = ["sponsor"];
        }
        {
          key = "ModifyChapters";
          remove_sponsor_segments = ["sponsor"];
        }
      ];
    };
    sponsorblock-mark = {
      postprocessors = [
        {
          key = "SponsorBlock";
          categories = [
            "sponsor"
            "intro"
            "outro"
            "selfpromo"
          ];
        }
        {
          key = "ModifyChapters";
          sponsorblock_chapter_title = "[SponsorBlock]: %(category_names)l";
        }
        {
          key = "FFmpegMetadata";
          add_chapters = true;
        }
      ];
    };
    gif = {
      final_ext = "gif";
      postprocessors = [
        {
          key = "FFmpegVideoConvertor";
          preferedformat = "gif";
        }
      ];
    };
    muted = {
      format = "bestvideo/best";
      postprocessor_args = {
        ffmpeg = ["-an"];
      };
    };
    best-compat-mp4 = {
      format_sort = [
        "vcodec:h264"
        "res"
        "acodec:m4a"
      ];
      merge_output_format = "mp4";
      postprocessors = [
        {
          key = "FFmpegVideoConvertor";
          preferedformat = "mp4";
        }
      ];
    };
    embed-metadata = {
      writethumbnail = true;
      postprocessors = [
        {
          key = "FFmpegMetadata";
          add_metadata = true;
          add_chapters = true;
          add_infojson = "if_exists";
        }
        {
          key = "EmbedThumbnail";
          already_have_thumbnail = false;
        }
      ];
    };
    subtitles = {
      writesubtitles = true;
      subtitleslangs = [
        "en.*"
        "-live_chat"
      ];
      postprocessors = [
        {
          key = "FFmpegEmbedSubtitle";
          already_have_subtitle = false;
        }
        {
          key = "FFmpegMetadata";
          add_chapters = true;
        }
      ];
    };
    max-1080p = {
      format = "bestvideo[height<=1080]+bestaudio/best[height<=1080]";
    };
    full = {
      merge_output_format = "mkv";
      allow_multiple_video_streams = true;
      allow_multiple_audio_streams = true;
      format = "bv*+mergeall[vcodec=none][language~='(?i)^(en|pl|ia|ina|tlh|klingon)']/bv*+ba/b";
      writethumbnail = true;
      writeinfojson = true;
      writesubtitles = true;
      writeautomaticsub = true;
      subtitleslangs = [
        "en.*"
        "pl.*"
        "ia.*"
        "ina.*"
        "tlh.*"
        "klingon.*"
        "-live_chat"
      ];
      postprocessors = [
        {
          key = "SponsorBlock";
          categories = [
            "sponsor"
            "intro"
            "outro"
            "selfpromo"
            "preview"
            "filler"
            "interaction"
            "music_offtopic"
          ];
          when = "after_filter";
        }
        {
          key = "ModifyChapters";
          sponsorblock_chapter_title = "[SponsorBlock]: %(category_names)l";
        }
        {
          key = "FFmpegEmbedSubtitle";
          already_have_subtitle = false;
        }
        {
          key = "FFmpegMetadata";
          add_metadata = true;
          add_chapters = true;
          add_infojson = true;
        }
        {
          key = "EmbedThumbnail";
          already_have_thumbnail = false;
        }
      ];
    };
  };

  presetsFile = (pkgs.formats.json {}).generate "metube-presets.json" presets;
in {
  options.features.server.web.metube = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "ytdlp";
        aliases = [
          "metube"
        ];
        port = 8081;
        suspend = "podman-metube.service";
      })
      {
        users.users.metube = {
          isSystemUser = true;
          group = "metube";
          home = "${storage}/metube";
          autoSubUidGidRange = true;
          linger = true;
          extraGroups = [
            "video"
            "render"
          ];
        };
        users.groups.metube = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/metube 0751 metube web - -"
          "z ${storage}/metube 0751 metube web - -"
          "d ${storage}/metube/downloads 0750 metube web - -"
          "z ${storage}/metube/downloads 0750 metube web - -"
        ];

        virtualisation.oci-containers.containers.metube = {
          image = helpers.resolveImage "ghcr.io/alexta69/metube:latest";
          podman.user = "metube";
          ports = [
            "127.0.0.1:8081:8081"
          ];
          devices = [
            "/dev/dri:/dev/dri"
          ];
          volumes = [
            "${storage}/metube/downloads:/downloads"
            "${presetsFile}:/etc/metube-presets.json:ro"
          ];
          environment = {
            CORS_ALLOWED_ORIGINS = "*";
            DELETE_FILE_ON_TRASHCAN = "true";
            CLEAR_COMPLETED_AFTER = lib.toString (60 * 3); # 3 mins
            YTDL_OPTIONS_PRESETS_FILE = "/etc/metube-presets.json";
          };
          extraOptions = [
            "--userns=keep-id:uid=1000,gid=1000"
          ];
        };
      }
    ]
  );
}
