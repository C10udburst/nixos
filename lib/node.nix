{lib, ...}: let
  # Helper for boolean leaf options gated on a parent node
  mkLeaf = {
    parent ? null,
    default ? false,
    ...
  } @ args:
    lib.mkOption (
      removeAttrs args ["parent"]
      // {
        type = lib.types.bool;
        default =
          if parent != null
          then
            (
              if (parent.enable or parent)
              then default
              else false
            )
          else default;
      }
    );

  # Helper for dendritic branches: coercedTo bool, enables alias, parent gating
  mkNode = {
    parent ? null,
    default ? false,
    options ? {},
    ...
  } @ args:
    lib.mkOption (
      removeAttrs args [
        "parent"
        "options"
      ]
      // {
        type = lib.types.coercedTo lib.types.bool (b: {enable = b;}) (
          lib.types.submodule (
            {config, ...}: {
              options =
                {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default =
                      if parent != null
                      then
                        (
                          if (parent.enable or parent)
                          then default
                          else false
                        )
                      else default;
                  };
                  enabled = lib.mkOption {
                    type = lib.types.bool;
                    default = config.enable;
                  };
                }
                // (
                  if builtins.isFunction options
                  then options {inherit config;}
                  else options
                );
            }
          )
        );
        default = {};
      }
    );
in {
  inherit mkLeaf mkNode;
  mkDendriticNode = mkNode;
  mkDendriticLeaf = mkLeaf;
}
