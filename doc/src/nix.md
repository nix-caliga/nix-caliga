# Nix
Nix-caliga does not require the nix package itself, or a nix-daemon to be on the bootc images it creates.  
However you may still want nix and the nix-daemon to be available on your system. `config.nix.enable` sets the nix-daemon up.  
This module is functional, but it is not yet fully featured, some aspects of the nix configuration are not easily accessible.  

Enabling `nix.enable` requires `caliga.core.etc-usr.enable`, `caliga.core.systemd.enable`, `caliga.core.tmpfiles.enable`, and `caliga.core.users.enable` to all be true.

## Writable /nix overlay
On a bootc system `/nix` is part of the read only image. To allow the Nix daemon to install packages and manage the nix store, we create an overlay mount over `/nix` with its upper directory at `/var/nix/upper` and work directory at `/var/nix/work` (/var being mutable and persistant). The overlay mount only occurs on systems where /nix is actually read only. In a container the overlay mount won't actually be created.

## Nix daemon
The nix-daemon service and socket units are pulled in through `systemd.packages` from the Nix package itself. It's not tested, but other "nix" packages should work in place.

## Image's nix database
If the nix-daemon is enabled, `layeredImage.includeNixDB` (see [buildImage](buildImage.md)) is set to true so that the Nix database from the image build is included. This allows the daemon to be aware of store paths that were baked into the image.

## Nix configuration
A `nix.conf` is placed at `/etc/nix/nix.conf` with flakes and the nix-command experimental features enabled along with the nixpkgs path set from the flake input. Additional settings can be configured through `nix.settings`.  
Eventually the nix-caliga nix-daemon will be more configurable. Hopefully pulling in more of the configuration directly from NixOS.

# Options
## `nix.*`
- `nix.enable`
  - Enable the Nix package and daemon.
- `nix.package`
  - The Nix package to use. Defaults to `pkgs.nix`.
- `nix.nrBuildUsers`
  - Number of Nix build users to create. Defaults to 32.
- `nix.settings`
  - Additional settings for nix.conf as an attrset. Merged with the (currently) fixed defaults (build-users-group, experimental-features, nix-path).
