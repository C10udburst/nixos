{
  lib,
  lockPath ? ../oci.lock,
  ...
}:
let
  ociLock =
    if builtins.pathExists lockPath then
      builtins.fromJSON (builtins.readFile lockPath)
    else
      { };

  resolveImage =
    image:
    let
      key = if lib.hasInfix ":" image then image else "${image}:latest";
    in
    ociLock.${key} or (ociLock.${image} or image);
in
{
  inherit resolveImage;
}
