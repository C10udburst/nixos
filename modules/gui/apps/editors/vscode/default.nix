{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.editors.vscode;
  editorsEnabled = config.features.gui.apps.editors.enable;

  # Extensions, their runtime toolchain and the overlay that fixes them up are
  # shared with the browser server in ./web.nix.
  ext = import ./_extensions.nix {inherit config lib pkgs;};
  userSettings = import ./_settings.nix;

  fhsVscode = pkgs.vscode.fhsWithPackages ext.vscode.sandboxPackages;

  ephemeralVscode = pkgs.symlinkJoin {
    name = "code";
    paths = [fhsVscode];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm $out/bin/code
      makeWrapper ${fhsVscode}/bin/code $out/bin/code \
        --run '
          REAL_CODE_DIR="''${HOME}/.config/Code"
          TEMP_DIR="/tmp/vscode-profile-''${USER}"

          # Ensure real directory structure exists
          mkdir -p "''${REAL_CODE_DIR}/User"

          # Recreate temp layout
          rm -rf "''${TEMP_DIR}"
          mkdir -p "''${TEMP_DIR}/User"

          # Link root items except User
          for item in "''${REAL_CODE_DIR}"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            if [ "$name" != "User" ]; then
              ln -sf "$item" "''${TEMP_DIR}/$name"
            fi
          done

          # Link User items except settings and keybindings
          for item in "''${REAL_CODE_DIR}/User"/*; do
            [ -e "$item" ] || continue
            name=$(basename "$item")
            if [ "$name" != "settings.json" ] && [ "$name" != "keybindings.json" ]; then
              ln -sf "$item" "''${TEMP_DIR}/User/$name"
            fi
          done

          # Copy settings and keybindings if they exist
          if [ -f "''${REAL_CODE_DIR}/User/settings.json" ]; then
            cp -Lf "''${REAL_CODE_DIR}/User/settings.json" "''${TEMP_DIR}/User/settings.json"
            chmod +w "''${TEMP_DIR}/User/settings.json"
          fi
          if [ -f "''${REAL_CODE_DIR}/User/keybindings.json" ]; then
            cp -Lf "''${REAL_CODE_DIR}/User/keybindings.json" "''${TEMP_DIR}/User/keybindings.json"
            chmod +w "''${TEMP_DIR}/User/keybindings.json"
          fi
        ' \
        --add-flags '--user-data-dir /tmp/vscode-profile-''${USER}' \
        --add-flags '--enable-features=UseOzonePlatform --ozone-platform=wayland'
    '';
  };
in {
  options.features.gui.apps.editors.vscode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = editorsEnabled && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        # Declared once for the whole feature: ./web.nix resolves the very same
        # registry through this input.
        nix-vscode-extensions = {
          url = "github:nix-community/nix-vscode-extensions";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }

    (lib.mkIf cfg.enable {
      nixpkgs.overlays = [
        (inputs.nix-vscode-extensions.overlays.default or (_: _: {}))
        ext.overlay
      ];

      home-manager.users.cloudburst = lib.mkMerge [
        (lib.mkIf (config.stylix.enable or false) {
          stylix.targets.vscode.enable = true;
        })
        {
          programs.vscode = {
            enable = true;
            package = ephemeralVscode;
            mutableExtensionsDir = false;

            profiles.default = {
              extensions = ext.vscode.extensions;
              inherit userSettings;
            };
          };

          xdg.mimeApps = {
            defaultApplications = {
              "text/javascript" = ["code.desktop"];
              "application/javascript" = ["code.desktop"];
              "text/x-python" = ["code.desktop"];
              "text/x-rust" = ["code.desktop"];
              "text/x-c" = ["code.desktop"];
              "text/x-c++" = ["code.desktop"];
              "text/x-go" = ["code.desktop"];
              "text/x-java" = ["code.desktop"];
              "text/x-shellscript" = ["code.desktop"];
              "application/json" = ["code.desktop"];
              "text/x-nix" = ["code.desktop"];
              "text/x-yaml" = ["code.desktop"];
              "text/x-toml" = ["code.desktop"];
              "text/x-ini" = ["code.desktop"];
              "text/x-xml" = ["code.desktop"];
              "text/x-sql" = ["code.desktop"];
              "text/x-php" = ["code.desktop"];
              "text/x-perl" = ["code.desktop"];
              "text/x-ruby" = ["code.desktop"];
              "text/x-lua" = ["code.desktop"];
              "text/x-haskell" = ["code.desktop"];
              "text/x-scala" = ["code.desktop"];
              "text/x-kotlin" = ["code.desktop"];
              "text/x-vb" = ["code.desktop"];
            };
            associations.added = {
              "inode/directory" = ["code.desktop"];
            };
          };
        }
      ];
    })
  ];
}
