{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.bootc.ostree-prepare-root;

  prepareRootConf = pkgs.writeText "prepare-root.conf" (
    lib.optionalString cfg.transientEtc ''
      [etc]
      transient = true
    ''
    + cfg.additionalConf
  );

in
{
  options.bootc.initramfs.regenerate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Regenerate the initramfs during the container build using caliga.core.containerfile.
        Requires `caliga.core.containerfile.enable = true`.
      '';
    };

    command = lib.mkOption {
      type = lib.types.str;
      # based off the current fedora 43's regenerate command
      default = "kver=$(cd /usr/lib/modules && echo *) && mkdir -p /tmp/dracut && dracut --reproducible -v --add ostree --tmpdir /tmp/dracut -f --no-hostonly /usr/lib/modules/$kver/initramfs.img --kver $kver";
      description = ''
        The command to run to regenerate the initramfs in the containerfile from caliga.core.containerfile
      '';
    };
  };

  # I believe the configuration in this file will be moving eslewhere soon
  # https://github.com/bootc-dev/bootc/issues/2079
  options.bootc.ostree-prepare-root = {
    # TODO there is likely a better way to handle this file creation, I'll review nixos for similar cases soon.
    createConf = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Enable to over-write the default prepare-root.conf file with bootc.ostree-prepare-root.transientEtc and bootc.ostree-prepare-root.additionalConf
        Enabled if transientEtc is enabled.
      '';
    };

    transientEtc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Enable ostree transient `/etc` mode.

        If this is set to true, then the /etc mount point is mounted transiently i.e. a non-persistent location.
        Encouraged by bootc to enable when possible.

        Sets `etc.transient = true` in `/usr/lib/ostree/prepare-root.conf`.
        See [ostree-prepare-root(1)](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html).

        If enabled, sets bootc.ostree-prepare-root.createConf to true
      '';
    };

    additionalConf = lib.mkOption {
      type = lib.types.lines;
      default = ''
        [composefs]
        enabled = yes
        [sysroot]
        readonly = true
      '';
      description = lib.mdDoc ''
        Additional configuration for `/usr/lib/ostree/prepare-root.conf`.

        See [ostree-prepare-root(1)](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html).
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.createConf {
      # needs mode set so that environment.usr doesn't use a symlink
      # symlink doesnt work as the file is read in initramfs
      environment.usr."lib/ostree/prepare-root.conf" = {
        source = prepareRootConf;
        mode = "0644";
      };
    })

    (lib.mkIf config.bootc.initramfs.regenerate.enable {
      caliga.core.containerfile.extraCommands = lib.mkAfter ''
        RUN ${config.bootc.initramfs.regenerate.command}
      '';

      warnings =
        lib.optional (!config.caliga.core.containerfile.enable) ''
          bootc.initramfs.regenerate is enabled but caliga.core.containerfile.enable is false.
          The initramfs will not be rebuilt automatically.
          Enable caliga.core.containerfile or rebuild the initramfs manually.
        ''
        ++
          lib.optional
            (config.caliga.core.containerfile.enable && config.caliga.core.containerfile.file != null)
            ''
              bootc.initramfs.regenerate is enabled but caliga.core.containerfile.file is set.
              The built-in initramfs regenerate command will not be used. You will need to add the regenerate command manually to your Containerfile.
            '';
    })

    (lib.mkIf cfg.transientEtc {
      assertions = [
        {
          assertion = config.caliga.core.systemd.enable;
          message = "bootc.ostree-prepare-root.transientEtc requires caliga.core.systemd.enable = true";
        }
      ];

      bootc.ostree-prepare-root.createConf = true;
      bootc.initramfs.regenerate.enable = lib.mkDefault true;
      warnings = lib.optional (!config.bootc.initramfs.regenerate.enable) ''
        bootc.ostree-prepare-root.transientEtc is enabled but bootc.initramfs.regenerate.enable is false.
        Either enable bootc.initramfs.regenerate.enable or handle the regeneration yourself.
      '';

      # TODO, issues with /etc/fstab https://github.com/bootc-dev/bootc/issues/364
      # boot.automount seems to be mounting the efi at /boot?
      # create our own mount service for /boot and /bootc/efi
      systemd.maskedUnits = [
        "boot.automount"
      ];
      systemd.mounts = [
        {
          what = "/dev/disk/by-label/boot";
          where = "/boot";
          type = "ext4";
          wantedBy = [ "local-fs.target" ];
          unitConfig = {
            DefaultDependencies = false;
            After = "systemd-remount-fs.service";
            Before = "local-fs.target";
          };
        }
        {
          what = "/dev/disk/by-label/EFI-SYSTEM";
          where = "/boot/efi";
          type = "vfat";
          wantedBy = [ "local-fs.target" ];
          unitConfig = {
            DefaultDependencies = false;
            After = "boot.mount";
            Before = "local-fs.target";
          };
        }
      ];
    })
  ];
}
