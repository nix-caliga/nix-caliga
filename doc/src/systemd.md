# Systemd
Systemd configuration is delivered through `streamLayeredImage.contents`, symlinking the nix store paths to their locations.  
Tmpfiles work slightly differently than systemd services, tmpfile configurations are added using `config.environment.usr` (a duplicate of `config.environment.etc` from NixOS).

Both `config.systemd.*`, and `config.systemd.tmpfiles` through `config.environment.usr` are placed in the /usr directory and not the /etc directory like on NixOS. See [etc-usr](etc-usr.md) for more information.

Optionally, selinux labels can be assigned with `config.caliga.core.selinux.enable`. See [selinux](selinux.md).  
Some upstream NixOS services will call scripts that do not end up in nix store paths that are labeled by default (such as with `pkgs.writeShellScript`).
The `config.selinux.labelServiceExecs` option accepts a list of systemd service names, and will ensure all of the service's exec paths (that are in the nix store) get `bin_t` selinux labels.

## Options

### Core Systemd

Enabled with `config.caliga.core.systemd.enable`.

These options should all be fully available and compatible with their upstream NixOS counterparts.

- `config.systemd.services`
- `config.systemd.targets`
- `config.systemd.timers`
- `config.systemd.sockets`
- `config.systemd.paths`
- `config.systemd.mounts`
- `config.systemd.automounts`
- `config.systemd.slices`
- `config.systemd.units`
- `config.systemd.packages`
- `config.systemd.globalEnvironment`
- `config.systemd.enableStrictShellChecks`

New options specific to nix-caliga:

- `config.systemd.maskedUnits`
  - a list of systemd units to mask
- `config.systemd.defaultUnit`
  - Same as nixos, but it can be left empty leaving the base image's default target.

### Tmpfiles

Enabled with `config.caliga.core.tmpfiles.enable`.

- `config.systemd.tmpfiles`
