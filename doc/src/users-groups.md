# Users & Groups
User and group management in nix-caliga, like [system-manager](https://github.com/numtide/system-manager), uses [userborn](https://github.com/nikstur/userborn) to configure users and groups during boot. The `config.users.*` options from NixOS are almost all supported.  

Enabling `config.caliga.core.users.enable` requires `config.caliga.core.etc-usr.enable`, `config.caliga.core.systemd.enable`, and `config.caliga.os` to be set.

## Userborn
Userborn runs as a systemd service early durring boot to create and update users and groups. The base image's `systemd-sysusers.service` is masked when `config.caliga.core.users` is enabled.

## Home Directories
On bootc, `/home` is typically a symlink to `/var/home` so that home directories persist across image updates. If the user has `createHome` as true, this is handled by building the `/home/*` symlink to `/var/home*` into the image.  
Currently NixOS' `config.users.defaultUserHome` does not exist, but per-user `config.users.users.<name>.home` is still configurable.

## OS-Specific Base Users and Groups

To add a user to a base image group with `config.users.users.*.extraGroups`, the group must have a GID in the config.  
Additionally, a few system users like `root` need their id's set as well.  
These ids differ between OS, so we set these as part of `config.caliga.os`.

## Options

Enabled with `config.caliga.core.users.enable`.

- `config.users.users`
- `config.users.groups`
- `config.users.mutableUsers`
  - Defaults to `true`
- `config.users.defaultUserShell`
- `config.users.enforceIdUniqueness`
- `config.users.allowNoPasswordLogin`

## Differences from NixOS

### Removed or Stubbed Options

- `config.users.defaultUserHome`
- `config.users.manageLingering`
- `config.users.users.<name>.openssh`
- `config.users.users.<name>.cryptHomeLuks`
- `config.users.users.<name>.pamMount`
- `config.users.users.<name>.subUidRanges/subGidRanges/autoSubUidGidRange`
- `config.users.users.<name>.expires`

### Changed Options

- `config.users.users.<name>.linger` Currently there is no `null` option, the user is either lingering, or not. `true` or `false` only.
- `config.users.users.<name>.shell` — needs to use the base image's shell such as `/usr/bin/zsh`, not a package like `pkgs.zsh` as `programs.${shell}.enable` does not exist.
