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
    ./firewall.nix
    "${pkgs.path}/nixos/modules/misc/meta.nix"
    "${pkgs.path}/nixos/modules/system/build.nix"
  ];

  options = {
    # system-manager handles these in their environment.nix

    environment.systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };

    environment.pathsToLink = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    # generic stubs
    boot.kernel.sysctl = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };

    boot.kernelPackages.kernel.version = lib.mkOption {
      type = lib.types.str;
      default = pkgs.linuxPackages.kernel.version;
    };

    system.stateVersion = lib.mkOption {
      type = lib.types.str;
    };

  };

}
