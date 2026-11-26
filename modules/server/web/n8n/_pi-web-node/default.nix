# The n8n-nodes-pi-web community node. Called with `import ./_pi-web-node` from the
# n8n module; the `_` prefix on this directory keeps its contents out of import-tree's
# module discovery, so this file is a plain helper and never a NixOS module.
#
# Plain CommonJS with no dependencies — Node's global fetch does the talking — so the
# build is a copy into the node_modules layout that the upstream module's
# N8N_CUSTOM_EXTENSIONS linkFarm expects: ${pkg}/lib/node_modules/${pkg.pname}. The
# pname is what the linkFarm names the entry, so it has to match the package name in
# package.json.
{
  pkgs,
  lib,
  version ? "0.1.0",
}: let
  pname = "n8n-nodes-pi-web";
in
  pkgs.stdenvNoCC.mkDerivation {
    inherit pname version;
    src = ./.;

    # No unpacking and no build: the sources go out as they are, and default.nix is
    # left behind because it builds the package instead of shipping in it.
    phases = ["installPhase"];
    installPhase = ''
      runHook preInstall
      dest="$out/lib/node_modules/${pname}"
      mkdir -p "$dest"
      cp -r "$src"/package.json "$src"/nodes "$src"/credentials "$src"/README.md "$dest"/
      chmod -R u+w "$dest"
      runHook postInstall
    '';

    meta = {
      description = "n8n node that opens a pi-web session, arms the EVO-X2 lease with /enqueue and sends the prompt";
      homepage = "https://github.com/agegr/pi-web";
      license = lib.licenses.mit;
    };
  }
