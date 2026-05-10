{
  config,
  pkgs,
  lib,
  utils,
  userborn,
  ...
}:
let
  # REMOVE when https://github.com/NixOS/nixpkgs/pull/483684 is merged
  userbornConfig = {
    groups = lib.mapAttrsToList (_: opts: {
      inherit (opts) name gid members;
    }) config.users.groups;

    users = lib.mapAttrsToList (_: opts: {
      inherit (opts)
        name
        uid
        group
        description
        home
        password
        hashedPassword
        hashedPasswordFile
        initialPassword
        initialHashedPassword
        ;
      isNormal = opts.isNormalUser;
      shell = utils.toShellPath opts.shell;
    }) (lib.filterAttrs (_: u: u.enable) config.users.users);
  };

  previousConfigPath = "/var/lib/userborn/previous-userborn.json";
  userbornConfigJson = pkgs.writeText "userborn.json" (builtins.toJSON userbornConfig);
in
{
  imports = [
    "${pkgs.path}/nixos/modules/services/system/userborn.nix"
  ];

  options = {
    system.activationScripts.users = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Stub. NixOS specific option required by upstream userborn module.";
    };

    system.etc.overlay.mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stub. NixOS specific option required by upstream userborn module.";
    };
  };

  config = {
    services.userborn.enable = lib.mkIf config.caliga.core.users.enable true;
    services.userborn.package = lib.mkIf config.caliga.core.users.enable userborn;

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
      # REMOVE when https://github.com/NixOS/nixpkgs/pull/483684 is merged
      environment = {
        USERBORN_MUTABLE_USERS = "true";
        USERBORN_PREVIOUS_CONFIG = previousConfigPath;
      };

      serviceConfig = {
        StateDirectory = "userborn";
        ExecStartPost = [
          "${pkgs.coreutils}/bin/ln -sf ${userbornConfigJson} ${previousConfigPath}"
        ];
      };
    };
  };
}
