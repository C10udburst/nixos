# Pi Web (github:agegr/pi-web) built from source.
#
# `next build` fetches Noto Sans Mono through `next/font/google`, which the
# sandbox forbids, so both layouts import a shim instead and the CSS variable
# the stylesheets already consume gets the client's own monospace stack.
{
  pkgs,
  src,
}: let
  npmDepsHash = "sha256-vbXuQyHzmHP4VUFGPxI/f3WH9Paxwlk+ZR3JXWZjw2A=";

  version = (builtins.fromJSON (builtins.readFile (src + "/package.json"))).version;

  fontShim = pkgs.writeText "pi-font-shim.ts" ''
    export function Noto_Sans_Mono (_options?: unknown): {
      className: string;
      style: string;
      variable: string;
    } {
      void _options;
      return { className: "", style: "", variable: "pi-local-mono" };
    }
  '';

  fontCss = pkgs.writeText "pi-font.css" ''
    /* packaged build: next/font/google replaced by the client fontconfig stack */
    .pi-local-mono {
      --font-noto-mono: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
    }
  '';
in
  pkgs.buildNpmPackage {
    pname = "pi-web";
    inherit version src npmDepsHash;

    postPatch = ''
      for layout in app/layout.tsx demo/app/layout.tsx; do
        grep -q 'from "next/font/google"' "$layout"
        cp ${fontShim} "$(dirname "$layout")/pi-font-shim.ts"
        sed -i 's#from "next/font/google"#from "./pi-font-shim"#' "$layout"
      done

      for sheet in app/globals.css demo/app/globals.css; do
        cat ${fontCss} >> "$sheet"
      done
    '';

    # node-pty ships prebuilt linux binaries, so nothing here needs node-gyp
    npmRebuildFlags = ["--ignore-scripts"];

    env = {
      NEXT_TELEMETRY_DISABLED = "1";
    };

    meta = {
      mainProgram = "pi-web";
    };
  }
