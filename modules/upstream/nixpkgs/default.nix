# stubs and glue for upstream modules. based off of system-manager's nix/modules/upstream/nixpkgs/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./users-groups.nix
    ./userborn.nix
    "${pkgs.path}/nixos/modules/misc/ids.nix"
    "${pkgs.path}/nixos/modules/misc/meta.nix"
  ];

  options = {
    # system-manager handles these in their environment.nix

    environment.pathsToLink = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    system.stateVersion = lib.mkOption {
      type = lib.types.str;
    };
  };
}
