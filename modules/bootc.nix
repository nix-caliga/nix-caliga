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
      transient=true
    ''
    + cfg.additionalConf
  );

in
{
  options.bootc.ostree-prepare-root = {
    transientEtc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Enable ostree transient `/etc` mode.

        If this is set to true, then the /etc mount point is mounted transiently i.e. a non-persistent location.
        Encouraged by bootc to enable when possible.

        Sets `etc.transient = true` in `/usr/lib/ostree/prepare-root.conf`.
        See [ostree-prepare-root(1)](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html).
      '';
    };

    additionalConf = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = lib.mdDoc ''
        Additional configuration included to `/usr/lib/ostree/prepare-root.conf`.
        See [ostree-prepare-root(1)](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html).
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.transientEtc || cfg.additionalConf != "") {
      # TODO considering maybe making an `environment.usr` for placing files in /usr?
      layeredImage.extraCommands = ''
        mkdir -p usr/lib/ostree
        cp ${prepareRootConf} usr/lib/ostree/prepare-root.conf
      '';
    })

    (lib.mkIf cfg.transientEtc {
      # etc.transient needs initramfs to regenerate to take effect
      build.postBuild.containerfile.extraCommands = lib.mkAfter ''
        RUN kver=$(cd /usr/lib/modules && echo *) && dracut --no-hostonly -vf /usr/lib/modules/$kver/initramfs.img $kver
      '';

      warnings =
        lib.optional (!config.build.postBuild.containerfile.enable) ''
          bootc.ostree-prepare-root.transientEtc is enabled but build.postBuild.containerfile.enable is false.
          The initramfs will not be rebuilt automatically.
          Enable build.postBuild.containerfile or rebuild the initramfs manually.
        ''
        ++ lib.optional (config.build.postBuild.containerfile.enable && config.build.postBuild.containerfile.file != null) ''
          bootc.ostree-prepare-root.transientEtc is enabled but build.postBuild.containerfile.file is set.
          The built-in initramfs regenerate command will not be used. You will need to add the regenerate command manually to your Containerfile.
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
