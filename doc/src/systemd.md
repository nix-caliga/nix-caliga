# Systemd
Systemd configuration is delivered through streamLayeredImage.contents, symlinking the nix store paths to their locations.  
Tmpfiles work slightly differently than systemd services, tmpfile configurations are added using environment.usr (a duplicate of environment.etc from NixOS).

Both `systemd`, and `systemd.tmpfiles` through `environment.usr` are placed in the /usr directory and not the /etc directoy like on NixOS. See [etc-usr](etc-usr.md) for more information.

Optionally, selinux labels can be assigned with `config.caliga.core.selinux.enable`. See [selinux](selinux.md).  
Some upstream NixOS services will call scripts that do not end up in nix store paths that are labeled by default (such as with pkgs.writeShellScript).
The `selinux.labelServiceExecs` option accepts a list of systemd service names, and will ensure all of the service's exec paths (that are in the nix store) get bin_t selinux labels.

# Options
These `systemd` options should all be fully available and compatable with their upstream NixOS counterparts.
## made available with `config.caliga.core.systemd.enable`
- `systemd.services`
- `systemd.targets`
- `systemd.timers`
- `systemd.sockets`
- `systemd.paths`
- `systemd.mounts`
- `systemd.automounts`
- `systemd.slices`
- `systemd.units`
- `systemd.packages`
- `systemd.globalEnvironment`
- `systemd.enableStrictShellChecks`

New options specific to nix-caliga
- `systemd.maskedUnits`
  - a list of systemd units to mask
- `systemd.defaultUnit`
  - Same as nixos, but it can be left empty leaving the base image's default target.


## made available with `config.caliga.core.tmpfiles.enable`
- `systemd.tmpfiles`
