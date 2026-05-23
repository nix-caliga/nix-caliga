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
    system.stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Stub. NixOS specific option required by upstream modules.";
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
  };
}
