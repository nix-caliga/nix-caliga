{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./buildImage.nix
    ./caliga.nix
    ./etc-usr.nix
    ./tmpfiles.nix
    ./systemd
    ./bootc.nix
    ./bootc-update.nix
    ./selinux.nix
    ./nix.nix
    ./operatingSystems
    ./upstream/nixpkgs
  ];

  options = {

    environment.systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };

    assertions = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      internal = true;
      default = [ ];
      example = [
        {
          assertion = false;
          message = "you can't enable this for that reason";
        }
      ];
      description = ''
        This option allows modules to express conditions that must
        hold for the evaluation of the system configuration to
        succeed, along with associated error messages for the user.
      '';
    };

    warnings = lib.mkOption {
      internal = true;
      default = [ ];
      type = lib.types.listOf lib.types.str;
      example = [ "The `foo' service is deprecated and will go away soon!" ];
      description = ''
        This option allows modules to show warnings to users during
        the evaluation of the system configuration.
      '';
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
        ];
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
