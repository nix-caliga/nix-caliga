# bootc

Nix-caliga is gradually increasing the number of bootc specific options over time.  
Mainly focused on Fedora, there will likely be a lot of breaking changes here as the Fedora-bootc image itself changes.

## ostree-prepare-root

`config.bootc.ostree-prepare-root` configures `/usr/lib/ostree/prepare-root.conf`.
This file is read during initramfs to configure how the root filesystem is set up at boot. See [ostree-prepare-root](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html).  
Because this file is read from the initramfs, any changes require regenerating the initramfs to take effect.

### Transient /etc

`bootc.ostree-prepare-root.transientEtc` mounts `/etc` as a transient overlay at boot. Changes to `/etc` are not persisted across reboots. This is [encouraged by upstream bootc](https://bootc.dev/bootc/filesystem.html#enabling-transient-etc) when possible.

Enabling `transientEtc` automatically:
- Enables `bootc.ostree-prepare-root.createConf`
- Enables `bootc.initramfs.regenerate` (so the initramfs picks up the new config)

When `transientEtc` is enabled, `boot.automount` is masked and replaced with mount units for `/boot` (ext4, by-label `boot`) and `/boot/efi` (vfat, by-label `EFI-SYSTEM`).  
This works around issues seemingly with `/etc/fstab` handling under transient etc.

Requires `caliga.core.systemd.enable = true`.

## Initramfs regeneration

Because `streamLayeredImage` cannot run commands against the base image's kernel or modules, initramfs regeneration must happen in a separate `podman build` step using a [Containerfile](buildImage.md). 
Setting `bootc.initramfs.regenerate = true` appends a `dracut` command to the generated Containerfile.

Requires `caliga.core.containerfile.enable = true`.

If `caliga.core.containerfile.file` is set the built-in dracut command is ignored in favor of your containerfile.

## Automatic updates (`services.bootc-update`)

The `services.bootc-update` module sets up a systemd timer that runs `bootc upgrade` on a schedule.  
It masks the upstream `bootc-fetch-apply-updates` units to avoid conflicts.

Requires `caliga.core.systemd.enable = true`.

### Registry authentication

Two options are provided for authenticating with private registries:

- `auth` builds `auth.json` into the image at `/etc/ostree/auth.json`. Credentials are baked in at image build time. Requires `caliga.core.etc-usr.enable` (see [etc-usr](etc-usr.md)) = true.
- `authFile` symlinks an existing file on the host to `/etc/ostree/auth.json` at runtime through tmpfiles. Requires `caliga.core.tmpfiles.enable = true`. Takes priority over `auth` if both are set.

Auth values are base64-encoded `user:pass` strings, generate with `echo -n 'user:pass' | base64`.

# Options

## `bootc.ostree-prepare-root`

- `createConf` Write `/usr/lib/ostree/prepare-root.conf` into the image. Defaults to `false`.
- `transientEtc` Mount `/etc` as a transient overlay at boot. Defaults to `false`.
- `additionalConf` Additional lines appended to `prepare-root.conf`. Defaults to enabling composefs and readonly sysroot.

## `bootc.initramfs`

- `regenerate` Append a dracut initramfs regeneration step to the Containerfile. Defaults to `false`.

## `services.bootc-update`

- `enable` Enable the automatic update timer.
- `autoReboot` Reboot after applying an update (`bootc upgrade --apply`). Defaults to `true`.
- `schedule.onBootSec` Delay after boot before the first update check. Defaults to `30s`.
- `schedule.onUnitActiveSec` Interval between update checks. Defaults to `1h`.
- `schedule.onCalendar` If set, overrides `onBootSec` and `onUnitActiveSec` with a calendar expression (e.g. `"daily"`). Defaults to `null`.
- `auth` Registry credentials baked into the image.
- `authFile` Path to a `containers-auth.json` file on the host, symlinked at runtime.
