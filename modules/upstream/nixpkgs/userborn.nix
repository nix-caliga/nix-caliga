# copied from system-manager's nix/modules/upstream/nixpkgs/userborn.nix
# adds: systemd-sysusers mask, explicit service ordering, alias removal for bootc compatibility
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

  services.userborn.enable = lib.mkDefault true;
  services.userborn.package = userborn;

  # Mask the base image's systemd-sysusers since userborn handles users/groups.
  systemd.maskedUnits = lib.mkIf config.services.userborn.enable [
    "systemd-sysusers.service"
  ];

  # REMOVE when https://github.com/NixOS/nixpkgs/pull/483684 is merged
  systemd.services.userborn = lib.mkIf config.services.userborn.enable {
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-remount-fs.service"
      "var.mount"
    ];
    before = [
      "systemd-tmpfiles-setup.service"
      "systemd-logind.service"
    ];
    conflicts = [ "shutdown.target" ];

    aliases = lib.mkForce [ ];

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
}
