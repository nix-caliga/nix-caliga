# Nix
Nix-caliga does not require the nix package itself, or a nix-daemon to be on the bootc images it creates.  
However you may still want nix and the nix-daemon to be available on your system. `config.nix.enable` sets the nix-daemon up, using a local-overlay-store on top of the nix store built into the image.  
Overlay stores are functional, but they do have some quirks to be aware of.

Enabling `config.nix.enable` requires:
- `config.caliga.core.etc-usr.enable = true`
- `config.caliga.core.systemd.enable = true`
- `config.caliga.core.tmpfiles.enable = true`
- `config.caliga.core.users.enable = true`
- `config.layeredImage.enableFakechroot = false`

## Local Overlay Store
On a bootc system `/nix` is part of the read only image. Nix-caliga sets the nix-daemon up with a [local-overlay-store](https://nix.dev/manual/nix/latest/store/types/experimental-local-overlay-store), using the image's nix store as a read only lower store and keeping all new store paths and Nix state in `/var/nix` (which is mutable and persistent).

- The image's `/nix` is bind mounted, private and read only to `/run/nix-lower/nix` and used as the lower store.
- `/nix/store` is an overlay mount with the lower directory at `/run/nix-lower/nix/store`, the upper directory at `/var/nix/store/upper` and work directory at `/var/nix/store/work`.
- Nix state and logs live in `/var/nix/var`, which is bind mounted back to `/nix/var` where they are expected to be.
- The image's `/nix/var/nix/gcroots/docker` is bind mounted to `/var/nix/var/nix/gcroots/docker` so the gcroots for the current image are always up to date for the upper store.
- The daemon socket is at `/nix/var/nix/daemon-socket/socket`.

## Running in a Container
To run the image as a container with full nix-daemon functionality, rootful and cap `SYS_ADMIN` are required.
Partial functionality may still be available rootless and without added capabilities.

Additionally to avoid OverlayFS issues, /var/nix for the upper store can't be on podman's default OverlayFS filesystem.
```
sudo podman run --cap-add SYS_ADMIN --tmpfs /var/nix <image>
```
To keep installed packages between runs mount `/var/nix` to persistent storage.

## Image Updates
Nix requires the lower store of a local-overlay-store to ["only grow, and not change in other ways"](https://nix.dev/manual/nix/latest/store/types/experimental-local-overlay-store). A bootc upgrade, rollback or switch will likely break that.
The upper store keeps its own database in `/var/nix/var/nix/db`. A package installed in the upper store will reference dependencies it needs from the lower store if they exist. This causes issues if those dependencies no longer exist after an image change.

`config.nix.onImageChange` chooses how to handle the upper store when the image's nix store changes. Defaults to `full-reset`.

### Detecting Changes
The image's gcroots in `/run/nix-lower/nix/var/nix/gcroots/docker` are used as a fingerprint of the lower store.
Early in boot, before `/nix/store` is mounted, `gcroots/docker` is compared with the previous fingerprint saved in `/var/nix/lower-store-roots`.  
- If it's the same (or lower-store-roots is empty) nothing happens.
- Otherwise the onImageChange services are triggered.

Currently there is no difference between a "growing" or "shrinking" lower store, any change to the store will result in the selected option's behavior.

### Attempt Repair
`attempt-repair` tries to repair the upper store. This will not solve all issues that may arise. Repair can only download paths again that a substituter has, paths that were built locally can't be restored this way.

- `nix-image-change-verify.service` runs offline before the nix-daemon starts.
  - `nix-store --optimise` removes paths from the upper store that the new image now provides, and `nix-store --verify` drops paths that disappeared and that nothing uses anymore.
  - `nix-store --verify` checks the paths in the upper store's database, including the references to the lower store it depends on.
- `nix-image-change-repair.service` runs `nix-store --verify --repair` through the daemon once the network is up.
  - Missing paths that installed packages still depend on are downloaded again from the substituters, this needs network access.

### Full Reset
`full-reset` deletes the upper store `/var/nix/store/upper`, `/var/nix/store/work`, `/var/nix/var` and user profiles, before `/nix/store` and `/nix/var` are mounted, then recreates them with tmpfiles.  

This is likely the most "supported" action as it will ensure that the store overlay operates correctly. But obviously it does mean that any contents in the upper store are gone.

### Do Nothing
`do-nothing` leaves `/var/nix` as is, stale paths stay registered. And the repair for any issues is left to you.

### Manual Reset
`systemctl start nix-upper-store-reset` wipes the upper store on a running system.  
It stops the nix-daemon, unmounts `/nix/store` and `/nix/var`, deletes `/var/nix/store/upper`, `/var/nix/store/work`, `/var/nix/var`, and deletes the per-user profiles before it recreates them empty with tmpfiles and mounts them again.

## Garbage Collection
`nix-collect-garbage` only deletes paths from the upper store, the image's paths are in the read only lower store and can't be deleted.  
Deleting a path that is in both layers has to bypass the overlay and delete it from `/var/nix/store/upper` directly, after which the overlay has to be remounted. The store is set up with a `remount-hook` that remounts `/nix/store` when this happens, the same applies to `nix-store --optimise`, which removes upper copies of paths the image now provides.

The `nix-gc.service` and the `config.nix.gc` options come from and are identical to the NixOS `nix-gc.nix` module.

## Nix Daemon
The nix-daemon service and socket units are pulled in through `config.systemd.packages` from the Nix package itself.  
`config.nix.package` should work with any "nix" package that has support for the `local-overlay-store` and `read-only-local-store` experimental features.
The nix-daemon service is overridden to pass the local-overlay-store as its store.

## Image Nix Database
If the nix-daemon is enabled, `config.layeredImage.includeNixDB` (see [buildImage](buildImage.md)) is set to `true` so that the Nix database from the image build is included.  

## Nix Configuration
A `nix.conf` is placed at `/etc/nix/nix.conf` with the defaults `store = daemon`, `build-users-group = nixbld`, the `nix-path` from [Pinned nixpkgs](#pinned-nixpkgs) and the `nix-command` and `flakes` experimental features enabled. Settings can be configured through `config.nix.settings`.
The `local-overlay-store` and `read-only-local-store` experimental features are always enabled, the overlay store requires them. 

### Pinned nixpkgs
`config.nix.nixpkgs` sets what `nixpkgs` points to, in `/etc/nix/registry.json`, by default it reuses the same pin as the image was built with.
Any path or flake input is pinned the same way, it's added to the image.
  ```nix
  nix.nixpkgs = inputs.nixpkgs-unstable;
  ```
If set to `null` it is left to the booted system to configure.

## Options

- `config.nix.enable`
  - Enable the Nix package and daemon using a local-overlay-store on top of the image's nix store.
- `config.nix.package`
  - The Nix package to use. Defaults to `pkgs.nix`.
- `config.nix.nrBuildUsers`
  - Number of Nix build users to create. Defaults to `32`.
- `config.nix.settings`
  - Settings for `nix.conf` see [Nix Configuration](#nix-configuration). `local-overlay-store` and `read-only-local-store` experimental features are always enabled.
- `config.nix.nixpkgs`
  - What `nixpkgs` is pinned to, a path or flake input, or `null` for unmanaged. Defaults to the nixpkgs the image is built with.
- `config.nix.gc`
  - Fully imported from the upstream NixOS `nix.gc` options.
- `config.nix.onImageChange`
  - What to do with the upper store in `/var/nix` when the image's nix store changes. One of `attempt-repair`, `full-reset` or `do-nothing`. Defaults to `full-reset`.
