# copied from system-manager's nix/modules/upstream/nixpkgs/userborn.nix
# adds: systemd-sysusers mask, alias removal for bootc compatibility
{
  config,
  pkgs,
  lib,
  utils,
  userborn,
  ...
}:
let
  userbornConfig = {
    groups = lib.mapAttrsToList (username: opts: {
      inherit (opts) name gid members;
    }) config.users.groups;

    users = lib.mapAttrsToList (username: opts: {
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
    };

    system.etc.overlay.mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    services.userborn.enable = lib.mkIf config.caliga.core.users.enable true;
    services.userborn.package = userborn;

    assertions = lib.mkIf config.caliga.core.users.enable [
      { assertion = config.caliga.core.systemd.enable; message = "caliga.core.users.enable requires caliga.core.systemd.enable = true"; }
      { assertion = config.caliga.core.etc.enable; message = "caliga.core.users.enable requires caliga.core.etc.enable = true"; }
    ];

    warnings = lib.optional (config.caliga.core.users.enable && !config.caliga.core.selinux.enable && !config.selinux.ignoreWarnings) ''
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

      # transientEtc needs this — etc.mount appears during boot with transient /etc
      after = lib.mkIf config.bootc.ostree-prepare-root.transientEtc [ "ostree-remount.service" ];
      # Remove systemd-tmpfiles-setup-dev.service
      before = lib.mkIf config.bootc.ostree-prepare-root.transientEtc (lib.mkForce [
        "sysinit.target"
        "shutdown.target"
        "sysinit-reactivation.target"
      ]);

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
