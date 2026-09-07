{
  lib,
  pkgs ? null,
  ...
} @ args: let
  nodeHelpers = import ./node.nix {inherit lib;};
  jinjaHelpers =
    if pkgs != null
    then import ./helpers/jinja.nix (args // {inherit pkgs lib;})
    else {};
in
  nodeHelpers // jinjaHelpers
