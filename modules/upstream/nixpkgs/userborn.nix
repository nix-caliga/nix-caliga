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
    };

    system.etc.overlay.mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    services.userborn.enable = lib.mkIf config.caliga.core.users.enable true;

    assertions = lib.mkIf config.caliga.core.users.enable [
      {
        assertion = config.caliga.core.systemd.enable;
        message = "caliga.core.users.enable requires caliga.core.systemd.enable = true";
      }
      {
        assertion = config.caliga.core.etc.enable;
        message = "caliga.core.users.enable requires caliga.core.etc.enable = true";
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

    # Mask the base image's systemd-sysusers since userborn handles users/groups.
    systemd.maskedUnits = lib.mkIf config.caliga.core.users.enable [
      "systemd-sysusers.service"
    ];

    systemd.services.userborn = lib.mkIf config.caliga.core.users.enable {
      # upstream aliases userborn to systemd-sysusers, which conflicts on bootc
      aliases = lib.mkForce [ ];

      # TODO possibly setup targets specifically for nix-caliga services can use
      after = [ "ostree-remount.service" ];
      # Remove systemd-tmpfiles-setup-dev.service
      before = (
        lib.mkForce [
          "sysinit.target"
          "shutdown.target"
          "sysinit-reactivation.target"
        ]
      );
    };
  };
}
