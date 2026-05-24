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

    # security-wrappers
    ./security-wrappers.nix
    "${pkgs.path}/nixos/modules/security/wrappers"
  ];

  options = {
    system.stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Stub. NixOS specific option required by upstream modules.";
    };

    system.checks = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Stub.";
    };

    # stubs required for home-manager
    system.userActivationScripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      description = "Stub";
    };

    fonts.fontconfig.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stub";
    };

    i18n.glibcLocales = lib.mkOption {
      type = lib.types.package;
      default = pkgs.glibcLocales;
      defaultText = lib.literalExpression "pkgs.glibcLocales";
      description = "Stub.";
    };

    systemd.user.services = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Stub.";
    };

    # stubs required for microvm.nix host module
    boot = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.anything;
        options.kernelModules = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };
      default = { };
      description = "Stub.";
    };

    security.pam.loginLimits = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = "Stub.";
    };

    virtualisation.libvirtd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stub.";
    };

    hardware.ksm.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stub.";
    };

    system.activationScripts.microvm-update-check = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Stub.";
    };
  };
}
