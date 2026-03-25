# compatibility stubs for upstream nixpkgs modules.
# closely follows system-manager's nix/modules/upstream/nixpkgs/default.nix
# changes:
#   removed firewall, nginx, nix, sops-nix imports
#   removed boot, services.openssh stubs
#   added environment.systemPackages, pathsToLink stubs (system-manager has these in environment.nix)
#   added system.etc.overlay.mutable stub (needed by upstream userborn module)
{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./users-groups.nix
    ./userborn.nix
    "${pkgs.path}/nixos/modules/misc/meta.nix"
    "${pkgs.path}/nixos/modules/misc/ids.nix"
    "${pkgs.path}/nixos/modules/services/system/userborn.nix"
    "${pkgs.path}/nixos/modules/system/build.nix"
  ];

  options = {
    # system-manager hanldes these in their environment.nix

    environment.systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };

    environment.pathsToLink = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    # nixos/modules/services/system/userborn.nix still depends on activation scripts
    # but just to verify that the "users" activation script is disabled.
    # We try to avoid having to import the whole activationScripts module.
    system.activationScripts.users = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    # stub: needed by upstream userborn module
    system.etc.overlay.mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

  };

}
