{
  lib,
  pkgs ? null,
  config ? null,
  ...
} @ args: let
  associations = import ./associations.nix {inherit lib;};
  jinja =
    if pkgs != null
    then import ./jinja.nix (args // {inherit pkgs lib config;})
    else {};
  oci = import ./oci.nix {inherit lib;};
in
  associations // jinja // oci
