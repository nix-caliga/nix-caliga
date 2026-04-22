{
  lib,
  config,
  ...
}:
{
  options.caliga.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable all core caliga modules (etc, systemd, tmpfiles, selinux, users).";
    };
    etc.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the /etc file generation module.";
    };
    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the systemd unit generation module.";
    };
    tmpfiles.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the systemd-tmpfiles module.";
    };
    selinux.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the SELinux file contexts module.";
    };
    users.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable user/group management via userborn.";
    };
  };

  config.caliga.core = lib.mkIf config.caliga.core.enable {
    etc.enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault true;
    tmpfiles.enable = lib.mkDefault true;
    selinux.enable = lib.mkDefault true;
    users.enable = lib.mkDefault true;
  };
}
