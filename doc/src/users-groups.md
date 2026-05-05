# Users & Groups
User and group management in nix-caliga, like [system-manager](https://github.com/numtide/system-manager), uses [userborn](https://github.com/nikstur/userborn) to configure users and groups during boot. The `config.users.*` options from NixOS are almost all supported.  

Enabling `caliga.core.users.enable` requires `caliga.core.etc-usr.enable`, `caliga.core.systemd.enable`, and `caliga.os` to be set.

### Userborn
Userborn runs as a systemd service early durring boot to create and update users and groups. The base image's `systemd-sysusers.service` is masked when `caliga.core.users` is enabled.

### Home directories
On bootc, `/home` is typically a symlink to `/var/home` so that home directories persist across image updates. If the user has `createHome` as true, this is handled by building the `/home/*` symlink to `/var/home*` into the image.  
Currently NixOS' `users.defaultUserHome` does not exist, but per-user `users.users.<name>.home` is still configurable.

### OS-specific base users and groups

To add a user to a base image group with `config.users.users.*.extraGroups`, the group must have a GID in the config.  
Additionally, a few system users like `root` need their id's set as well.  
These ids differ between OS, so we set these as part of `config.caliga.os`.

# Options
## made available with `config.caliga.core.users.enable`
- `users.users`
- `users.groups`
- `users.mutableUsers`
- `users.defaultUserShell`
- `users.enforceIdUniqueness`
- `users.allowNoPasswordLogin`

## Differences from NixOS

### Options removed from nix-caliga

- `users.defaultUserHome`
- `users.manageLingering`

### Options changed from NixOS

- `users.users.<name>.linger` Currently there is no `null` option, the user is either lingering, or not. `true` or `false` only.
