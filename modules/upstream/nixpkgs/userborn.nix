{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    "${pkgs.path}/nixos/modules/services/system/userborn.nix"
  ];

  options = {
    system.activationScripts.users = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Stub.";
    };

    system.etc.overlay.mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stub.";
    };
  };

  config = {
    services.userborn.enable = lib.mkIf config.caliga.core.users.enable true;

    assertions = lib.mkIf config.caliga.core.users.enable [
      {
        assertion = config.caliga.os != null;
        message = "caliga.core.users.enable requires caliga.os to be set. Users and groups are defined per OS.";
      }
      {
        assertion = config.caliga.core.systemd.enable;
        message = "caliga.core.users.enable requires caliga.core.systemd.enable = true";
      }
      {
        assertion = config.caliga.core.etc-usr.enable;
        message = "caliga.core.users.enable requires caliga.core.etc-usr.enable = true";
      }
    ];

    warnings =
      lib.optional
        (
          config.caliga.core.users.enable
          && !config.caliga.core.selinux.enable
          && !config.selinux.ignoreWarnings
        )
        ''
          caliga.core.users.enable is active but caliga.core.selinux.enable is false.
          Userborn may fail if selinux is enforcing.
          Enable caliga.core.selinux.enable or set selinux.ignoreWarnings = true to silence this warning.
        '';

    # the built in tmpfile rule to create /var/home ends up running after the userborn homedir tmpfile rules.
    # meaning the symlink from /home to /var/home is broken when userborn needs it.
    layeredImage.fakeRootCommands = lib.mkIf config.caliga.core.users.enable ''
      mkdir -p var/home
    '';

    systemd.services.userborn = lib.mkIf config.caliga.core.users.enable {
      # upstream aliases userborn to systemd-sysusers, which conflicts on bootc
      aliases = lib.mkForce [ ];

      # for transient etc
      after = [ "ostree-remount.service" ];
      # Drop systemd-tmpfiles-setup-dev.service from upstream's `before` but add
      # systemd-tmpfiles-setup.service so that home directories still get created
      before = (
        lib.mkForce [
          "sysinit.target"
          "shutdown.target"
          "sysinit-reactivation.target"
          "systemd-tmpfiles-setup.service"
        ]
      );
    };
  };
}
