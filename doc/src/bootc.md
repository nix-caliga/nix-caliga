# Bootc

Nix-caliga is gradually increasing the number of bootc specific options over time.  
Mainly focused on Fedora, there will likely be a lot of breaking changes here as the Fedora-bootc image itself changes.

## Ostree-prepare-root

`config.bootc.ostree-prepare-root` configures `/usr/lib/ostree/prepare-root.conf`.
This file is read during initramfs to configure how the root filesystem is set up at boot. See [ostree-prepare-root](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html).  
Because this file is read from the initramfs, any changes require regenerating the initramfs to take effect.

### Transient /etc

`config.bootc.ostree-prepare-root.transientEtc` mounts `/etc` as a transient overlay at boot. Changes to `/etc` are not persisted across reboots. This is [encouraged by upstream bootc](https://bootc.dev/bootc/filesystem.html#enabling-transient-etc) when possible.

Enabling `config.bootc.ostree-prepare-root.transientEtc` automatically:
- Enables `config.bootc.ostree-prepare-root.createConf`
- Enables `config.bootc.initramfs.regenerate.enable` (so the initramfs picks up the new config)

When `config.bootc.ostree-prepare-root.transientEtc` is enabled, `boot.automount` is masked and replaced with mount units for `/boot` (ext4, by-label `boot`) and `/boot/efi` (vfat, by-label `EFI-SYSTEM`).  
This works around issues seemingly with `/etc/fstab` handling under transient etc.

Requires `config.caliga.core.systemd.enable = true`.

## Initramfs Regeneration

Because `streamLayeredImage` cannot run commands against the base image's kernel or modules, initramfs regeneration must happen in a separate `podman build` step using a [Containerfile](buildImage.md). 
Setting `config.bootc.initramfs.regenerate.enable = true` adds `config.bootc.initramfs.regenerate.command` to the end of the generated containerfile. The command defaults to running `dracut`.

Requires `config.caliga.core.containerfile.enable = true`.

If `config.caliga.core.containerfile.file` is set the built-in dracut command is ignored in favor of your containerfile.

## Automatic Updates

The `config.services.bootc-update` module sets up a systemd timer that runs `bootc upgrade` on a schedule.  
It masks the upstream `bootc-fetch-apply-updates` units to avoid conflicts.

Requires `config.caliga.core.systemd.enable = true`.

### Registry Authentication

Two options are provided for authenticating with private registries:

- `config.services.bootc-update.auth`
  - Builds `auth.json` into the image at `/etc/ostree/auth.json`. Credentials are baked in at image build time. Requires `config.caliga.core.etc-usr.enable` (see [etc-usr](etc-usr.md)) = true.
- `config.services.bootc-update.authFile`
  - Symlinks an existing file on the host to `/etc/ostree/auth.json` at runtime through tmpfiles. Requires `config.caliga.core.tmpfiles.enable = true`. Takes priority over `config.services.bootc-update.auth` if both are set.

Auth values are base64-encoded `user:pass` strings, generate with `echo -n 'user:pass' | base64`.

## Options

### `config.bootc.ostree-prepare-root`

- `config.bootc.ostree-prepare-root.createConf`
  - Write `/usr/lib/ostree/prepare-root.conf` into the image. Defaults to `false`.
- `config.bootc.ostree-prepare-root.transientEtc`
  - Mount `/etc` as a transient overlay at boot. Defaults to `false`.
- `config.bootc.ostree-prepare-root.additionalConf`
  - Additional lines appended to `prepare-root.conf`. Defaults to enabling composefs and readonly sysroot.

### `config.bootc.initramfs`

- `config.bootc.initramfs.regenerate.enable`
  - Add an initramfs regeneration step to `caliga.core.containerfile`. Defaults to `false`.
- `config.bootc.initramfs.regenerate.command`
  - The command to run to regenerate the initramfs. Defaults to a `dracut` command.

### `config.services.bootc-update`

- `config.services.bootc-update.enable`
  - Enable the automatic update timer.
- `config.services.bootc-update.autoReboot`
  - Reboot after applying an update (`bootc upgrade --apply`). Defaults to `true`.
- `config.services.bootc-update.schedule.onBootSec`
  - Delay after boot before the first update check. Defaults to `30s`.
- `config.services.bootc-update.schedule.onUnitActiveSec`
  - Interval between update checks. Defaults to `1h`.
- `config.services.bootc-update.schedule.onCalendar`
  - If set, overrides `config.services.bootc-update.schedule.onBootSec` and `config.services.bootc-update.schedule.onUnitActiveSec` with a calendar expression (e.g. "daily"). Defaults to `null`.
- `config.services.bootc-update.auth`
  - Registry credentials baked into the image.
- `config.services.bootc-update.authFile`
  - Path to a `containers-auth.json` file on the host, symlinked at runtime.
