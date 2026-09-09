{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.theme.editors;
in {
  options.features.gui.theme.editors = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.theme.enable && true;
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.cloudburst = {config, ...}: let
      c = config.lib.stylix.colors.withHashtag;
      kateTheme = {
        metadata = {
          copyright = ["Stylix"];
          name = "Stylix";
          revision = 1;
        };
        editor-colors = {
          BackgroundColor = c.base00;
          BracketMatching = c.base03;
          CodeFolding = c.base02;
          CurrentLine = c.base01;
          CurrentLineNumber = c.base04;
          IconBorder = c.base01;
          IndentationLine = c.base03;
          LineNumbers = c.base03;
          MarkBookmark = c.base0D;
          MarkBreakpointActive = c.base08;
          MarkBreakpointDisabled = c.base0E;
          MarkBreakpointReached = c.base0A;
          MarkError = c.base08;
          MarkExecution = c.base0C;
          MarkWarning = c.base09;
          ModifiedLines = c.base09;
          ReplaceHighlight = c.base0B;
          SavedLines = c.base0B;
          SearchHighlight = c.base0A;
          Separator = c.base03;
          SpellChecking = c.base08;
          TabMarker = c.base03;
          TemplateBackground = c.base01;
          TemplateFocusedPlaceholder = c.base0B;
          TemplatePlaceholder = c.base0B;
          TemplateReadOnlyPlaceholder = c.base08;
          TextSelection = c.base02;
          WordWrapMarker = c.base03;
        };
        text-styles = {
          Alert = {
            background-color = c.base08;
            bold = true;
            selected-text-color = c.base07;
            text-color = "#000000";
          };
          Annotation = {
            selected-text-color = c.base05;
            text-color = c.base04;
          };
          Attribute = {
            selected-text-color = c.base07;
            text-color = c.base0D;
          };
          BaseN = {
            selected-text-color = c.base07;
            text-color = c.base09;
          };
          BuiltIn = {
            selected-text-color = c.base0D;
            text-color = c.base0D;
          };
          Char = {
            selected-text-color = c.base06;
            text-color = c.base0C;
          };
          Comment = {
            italic = true;
            selected-text-color = c.base07;
            text-color = c.base03;
          };
          CommentVar = {
            selected-text-color = c.base0C;
            text-color = c.base0C;
          };
          Constant = {
            bold = true;
            selected-text-color = c.base09;
            text-color = c.base09;
          };
          ControlFlow = {
            bold = true;
            selected-text-color = c.base07;
            text-color = c.base09;
          };
          DataType = {
            selected-text-color = c.base07;
            text-color = c.base0A;
          };
          DecVal = {
            selected-text-color = c.base07;
            text-color = c.base09;
          };
          Documentation = {
            selected-text-color = c.base08;
            text-color = c.base08;
          };
          Error = {
            selected-text-color = c.base08;
            text-color = c.base08;
            underline = true;
          };
          Extension = {
            bold = true;
            selected-text-color = c.base0D;
            text-color = c.base0D;
          };
          Float = {
            selected-text-color = c.base07;
            text-color = c.base09;
          };
          Function = {
            selected-text-color = c.base07;
            text-color = c.base0D;
          };
          Import = {
            selected-text-color = c.base0F;
            text-color = c.base0F;
          };
          Information = {
            selected-text-color = c.base0C;
            text-color = c.base0C;
          };
          Keyword = {
            bold = true;
            selected-text-color = c.base07;
            text-color = c.base0E;
          };
          Normal = {
            selected-text-color = c.base07;
            text-color = c.base05;
          };
          Operator = {
            selected-text-color = c.base07;
            text-color = c.base05;
          };
          Others = {
            selected-text-color = c.base07;
            text-color = c.base0A;
          };
          Preprocessor = {
            selected-text-color = c.base0B;
            text-color = c.base0B;
          };
          RegionMarker = {
            background-color = c.base04;
            selected-text-color = c.base07;
            text-color = c.base07;
          };
          SpecialChar = {
            selected-text-color = c.base06;
            text-color = c.base0C;
          };
          SpecialString = {
            selected-text-color = c.base0F;
            text-color = c.base0F;
          };
          String = {
            selected-text-color = c.base07;
            text-color = c.base0B;
          };
          Variable = {
            selected-text-color = c.base08;
            text-color = c.base08;
          };
          VerbatimString = {
            selected-text-color = c.base0B;
            text-color = c.base0B;
          };
          Warning = {
            selected-text-color = c.base0A;
            text-color = c.base0A;
          };
        };
      };
    in {
      xdg.dataFile."org.kde.syntax-highlighting/themes/Stylix.theme".text =
        builtins.toJSON kateTheme;

      programs.plasma.configFile = {
        "katerc" = {
          "KTextEditor Renderer" = {
            "Auto Color Theme Selection" = false;
            "Color Theme" = "Stylix";
          };
        };
        "kwriterc" = {
          "KTextEditor Renderer" = {
            "Auto Color Theme Selection" = false;
            "Color Theme" = "Stylix";
          };
        };
      };
    };
  };
}
