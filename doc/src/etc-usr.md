# Etc & Usr
NixOS makes heavy use of /etc, placing most of the system configuration there.
By default on Bootc, /etc and /var are the only two mutable locations where the running system's edits will persist. /etc specifically is handled with a three way merge. (See [bootc docs](https://bootc.dev/bootc/filesystem.html#etc))  
Bootc upstream recommends configuring your system with /usr instead of /etc where possible. (See [bootc docs](https://bootc.dev/bootc/filesystem.html)) And if possible even enabling a transient etc that is reset on reboot. (More details on this below)

For Nix-caliga this means shifting as much configuration to /usr as we can.  
While `environment.etc` will work functionally identically to how it does on NixOS, we have also added `environment.usr` with identical options to etc that can handle /usr files.  
`systemd.*` options are also configured to use /usr and not /etc.

Both `environment.etc` and `environment.usr` by default symlink files into place through streamLayeredImage.contents, pointing into the nix store.
If a `mode` is set (`"0600"` etc), the file is instead copied as a real file using fakeRootCommands with the specified permissions. This is necessary for files read early in boot (SELinux configs, ostree-prepare-root, etc.) where symlinks into the nix store won't work.

Symlinked files resolve into /nix/store paths. If SELinux is enforcing on the base image, enable `caliga.core.selinux.enable` to ensure proper labelling. See [selinux](selinux.md).

Transient etc is made available through `bootc.ostree-prepare-root.transientEtc` which will configure the /usr/lib/ostree/prepare-root.conf file for transient etc. I recommend looking over `bootc.ostree-prepare-root.additionalConf` and verifying the prepare-root.conf file has the full set of configuration that you need. (See [bootc docs](https://bootc.dev/bootc/filesystem.html#enabling-transient-etc) and [ostree-prepare-root](https://ostreedev.github.io/ostree/man/ostree-prepare-root.html))
In order for prepare-root.conf changes to take effect, you **must** regenerate the initramfs.  
`pkgs.dockerTools.streamLayeredImage` is unable to regenerate the image's initramfs, and this must be done with podman. `bootc.ostree-prepare-root.transientEtc` will configure a containerfile with a simple regenerate command.
If `caliga.core.containerfile.enable` is true, then after the streamLayeredImage completes, podman will run using the containerfile on the image before streaming the image itself. (See [buildImage](buildImage.md))  

As a side note, currently the transientEtc option only works for Fedora, and not for uBlue images which handle initramfs differently.

### `environment.systemPackages`
Packages in `environment.systemPackages` have their binaries symlinked into `/usr/local/bin` so they can be used by sudo without configuring `secure_path`.

# Options
These options should all be fully available and compatible with their upstream NixOS counterparts.
## made available with `config.caliga.core.etc-usr.enable`
- `environment.etc`
  - Files to be placed in /etc
- `environment.usr`
  - Files to be placed in /usr
- `environment.systemPackages`
  - Packages made available to all users at `/usr/local/bin`
