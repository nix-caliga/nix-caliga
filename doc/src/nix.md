# Nix
Nix-caliga does not require the nix package itself, or a nix-daemon to be on the bootc images it creates.  
However you may still want nix and the nix-daemon to be available on your system. `config.nix.enable` sets the nix-daemon up.  
This module is functional, but it is not yet fully featured, some aspects of the nix configuration are not easily accessible.  

Enabling `config.nix.enable` requires `config.caliga.core.etc-usr.enable`, `config.caliga.core.systemd.enable`, `config.caliga.core.tmpfiles.enable`, and `config.caliga.core.users.enable` to all be true.

## Nix Daemon
The nix-daemon service and socket units are pulled in through `config.systemd.packages` from the Nix package itself. It's not tested, but other "nix" packages should work in place.

## Image Nix Database
If the nix-daemon is enabled, `config.layeredImage.includeNixDB` (see [buildImage](buildImage.md)) is set to `true` so that the Nix database from the image build is included. This allows the daemon to be aware of store paths that were baked into the image.

## Nix Configuration
A `nix.conf` is placed at `/etc/nix/nix.conf` with flakes and the nix-command experimental features enabled along with the nixpkgs path set from the flake input. Additional settings can be configured through `config.nix.settings`.  
Eventually the nix-caliga nix-daemon will be more configurable. Hopefully pulling in more of the configuration directly from NixOS.

## Options

- `config.nix.enable`
  - Enable the Nix package and daemon.
- `config.nix.package`
  - The Nix package to use. Defaults to `pkgs.nix`.
- `config.nix.nrBuildUsers`
  - Number of Nix build users to create. Defaults to `32`.
- `config.nix.settings`
  - Additional settings for `nix.conf` as an attrset. Merged with the (currently) fixed defaults (`build-users-group`, `experimental-features`, `nix-path`).
