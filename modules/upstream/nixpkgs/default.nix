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
    ./openssh.nix
    ./programs/ssh.nix
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

    networking.enableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable IPv6 networking.";
    };

    boot.kernelPackages.kernel.version = lib.mkOption {
      type = lib.types.str;
      default = pkgs.linuxPackages.kernel.version;
    };

    system.stateVersion = lib.mkOption {
      type = lib.types.str;
    };

  };

  config =
    let
      systemPath = pkgs.buildEnv {
        name = "system-path";
        paths = config.environment.systemPackages;
        pathsToLink = [
          "/bin"
          "/sbin"
        ]
        ++ config.environment.pathsToLink;
      };
    in
    lib.mkIf (config.environment.systemPackages != [ ]) {

      # TODO
      # not sure if this is the best option
      # I want to make nix packages built into the bootc image available to sudo
      # Trying to avoid needing to control secure_path
      layeredImage.extraCommands = ''
        mkdir -p usr/local/bin
        for dir in ${systemPath}/bin ${systemPath}/sbin; do
          [ -d "$dir" ] && for bin in "$dir"/*; do
            ln -sf "$bin" usr/local/bin/
          done
        done
      '';
    };

}
