{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.vencord;
in {
  options.homeSettings.vencord = {
    enable = lib.mkEnableOption "Enable Vencord Discord client";
  };

  config = lib.mkIf cfg.enable {
    programs.vesktop = {
      enable = true;

      settings = lib.mkMerge [
        {
          appBadge = false;
          arRPC = true;
          disableMinSize = true;
          enableSplashScreen = false;
          tray = true;
          hardwareAcceleration = true;
          discordBranch = "stable";
        }
      ];

      vencord = {
        settings = {
          autoUpdate = true;
          autoUpdateNotification = false;
          disableMinSize = true;
          notifyAboutUpdates = false;

          plugins = {
            AlwaysTrust.enabled = true;
            BlurNSFW.enabled = true;
            ClearURLs.enabled = true;
            Experiments.enabled = true;
            CallTimer.enabled = true;
            FakeNitro = {
              enabled = true;
              enableEmojiBypass = true;
              emojiSize = 48;
              transformEmojis = true;
              enableStickerBypass = true;
              stickerSize = 160;
              transformStickers = true;
              transformCompoundSentence = false;
              enableStreamQualityBypass = true;
            };
            CharacterCounter.enabled = true;
            DisableCallIdle.enabled = true;
            ForceOwnerCrown.enabled = true;
            FixYoutubeEmbeds.enabled = true;
            ImageFilename.enabled = true;
            NoF1.enabled = true;
            GifPaste.enabled = true;
            ImageLink.enabled = true;
            NoOnboardingDelay.enabled = true;
            NormalizeMessageLinks.enabled = true;
            PictureInPicture.enabled = true;
            PlatformIndicators.enabled = true;
            ShowHiddenChannels.enabled = true;
            FriendInvites.enabled = false;
            iLoveSpam.enabled = true;
            ValidReply.enabled = true;
            ValidUser.enabled = true;
            MessageLogger = {
              enabled = true;
              ignoreSelf = true;
            };
            PinDMs.enabled = true;
            WebKeybinds.enabled = true;
            WebScreenShareFixes.enabled = true;
            ImageZoom.enabled = true;
            YoutubeAdblock.enabled = true;
            VoiceDownload.enabled = true;
            VoiceMessages.enabled = true;
            BetterUploadButton.enabled = true;
            ViewIcons.enabled = true;

            PermissionsViewer.enabled = true;
            TypingTweaks.enabled = true;
            UnsuppressEmbeds.enabled = true;
            ViewRaw.enabled = true;
            ShowTimeoutDuration.enabled = true;
            Summaries.enabled = true;
            BetterSessions.enabled = true;
            BetterGifPicker.enabled = true;
            SilentTyping = {
              enabled = true;
              showIcon = true;
            };
            BiggerStreamPreview.enabled = true;
            MemberCount.enabled = true;
            SpotifyCrack.enabled = true;
            FixImagesQuality.enabled = true;
            VencordToolbox.enabled = true;
            ShowHiddenThings.enabled = true;
            NoUnblockToJump.enabled = true;
            ServerListIndicators = {
              enabled = true;
              mode = 3;
            };
            NoTrack = {
              enabled = true;
              disableAnalytics = true;
            };
            TypingIndicator = {
              enabled = true;
              includeMutedChannels = false;
              includeBlockedUsers = true;
            };
          };

          useQuickCss = true;
        };

        useSystem = true;
      };
    };
  };
}
