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
      description = "Enable core caliga modules (etc, systemd, tmpfiles, selinux, users). Containerfile is enabled seperately";
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

    # Not sure this should be handled by nix-caliga, but it is opt in.
    # If enabled, it takes the image built by nix, and runs it over with a containerfile in podman.
    # streamLayeredImage is limited in the changes it can make. It can't regen the initramfs for example.
    containerfile = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Apply a Containerfile on top of the streamLayeredImage output.
          Using for tasks like regenerating the initramfs as streamLayeredImage cannot do this.
        '';
      };
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a Containerfile. Takes precedence over containerfile.extraCommands and generated commands if set.";
      };
      extraCommands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Containerfile commands included along side generated commands. Applied after streamLayeredImage.";
      };
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
