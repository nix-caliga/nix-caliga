<div align="center">

# Nix-caliga
Snow boot(c)

</div>

<br>

Nix-caliga aims to be to bootc images what [system-manager](https://github.com/numtide/system-manager) and [nix-darwin](https://github.com/nix-community/nix-darwin) are to Linux and macOS.

Using NixOS-like configuration, nix-caliga builds `pkgs.dockerTools.streamLayeredImage` outputs to configure bootc images.

## Current features

> Currently in the early stages.  
> Heavily based on numtide's [system-manager](https://github.com/numtide/system-manager), with a number of modules copied directly from it and adjusted to work with bootc image layering.

Core functionality such as `environment.etc`, `users.users`, `systemd.services` are all in place, as well as SELinux support, optional nix-daemon installation and others.  
For full details check [the documentation](nix-caliga.github.io/nix-caliga/) or review the code itself at [/modules](https://github.com/nix-caliga/nix-caliga/tree/main/modules).  
Support for Agenix, Home-manager and Microvm.nix is available out of the box for testing as well. See the [/examples](https://github.com/nix-caliga/nix-caliga/tree/main/examples).  

## Tested images

Fedora-bootc is the primary image that I am working with and is the focus. Thankfully most common bootc images are also based on Fedora.  
I have done minimal testing with these other bootc images. But everything appears to be working.

| Image | `caliga.os` | Notes |
| --- | --- | --- |
| [fedora-bootc](https://quay.io/repository/fedora/fedora-bootc) | `fedora` | Target focus for this project |
| [fedora-base-atomic](https://quay.io/repository/fedora-ostree-desktops/base-atomic) | `fedora` | |
| [fedora-kinoite](https://quay.io/repository/fedora-ostree-desktops/kinoite) | `fedora` | |
| [fedora-silverblue](https://quay.io/repository/fedora-ostree-desktops/silverblue) | `fedora` | |
| [ublue-aurora](https://github.com/ublue-os/aurora) | `fedora` | |
| [ublue-base-main](https://github.com/ublue-os/main) | `fedora` | |
| [ublue-bazzite](https://github.com/ublue-os/bazzite) | `fedora` | |
| [ublue-bluefin](https://github.com/ublue-os/bluefin) | `fedora` | |
| [ublue-kinoite-main](https://github.com/ublue-os/main) | `fedora` | |
| [ublue-silverblue-main](https://github.com/ublue-os/main) | `fedora` | |
| [ublue-ucore](https://github.com/ublue-os/ucore) | `fedora` | |
| [ublue-bluefin-dakota](https://github.com/projectbluefin/dakota) | `gnomeOS` | Doesn't use OSTree or Dracut |


### OSTree limitations
OSTree and the Nix Store both have similar functions as a "store" for independant roots, but they go about it differently.  
Putting a nix store into ostree seems to run into issues as both grow in size, eventually running into the cap for hard links.  
This appears to be due to how OSTree handles xattrs objects, and `file-xattrs-link`s.  

If you run into this issue when updating to a new image, or when building a vm etc, I recommend switching to a filesystem that supports larger numbers of links like xfs.

**Composefs**(An alternative to OSTree for bootc) does **not** appear to have this limitation, and base images using composefs should work smoothly. Projectbluefin/dakota is an example of a composefs bootc image.  
I believe the bootc project is slowly moving to Composefs from OSTree, so eventually this should become a non-issue.

## Getting started

Here is an example flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "github:nix-caliga/nix-caliga";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-caliga, ... }:
    {
      caligaConfigurations.x86_64-linux = {
        myimage = nix-caliga.lib.makeCaligaConfigurations {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [ ./images/myimage ];
        };
      };
    };
}
```

And an example caligaConfiguration (placed at ./images/myimage relative to the flake.nix)
Check `pkgs.dockerTools.pullImage` documentation to setup the `fromImage`
```nix
{ pkgs, ... }:

{
  config = {
    layeredImage = {
      name = "ghcr.io/nix-caliga/nix-caliga";
      tag = "test";
      fromImage = pkgs.dockerTools.pullImage {
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:9d7a12d886dd2a50589d141b3d71d5dad520b3e131680356dccd484bc171e03e";
        hash = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
        finalImageTag = "43";
      };
    };

    caliga.os = "fedora";
    caliga.core.enable = true;

    system.stateVersion = "25.11";

    users.users.example = {
      isNormalUser = true;
      uid = 1001;
      description = "Example User";
      initialPassword = "password";
    };

    environment.systemPackages = [ pkgs.cowsay ];

    services.bootc-update = {
      enable = true;
      schedule = {
        onBootSec = "20s";
        onUnitActiveSec = "2h";
      };
    };
  };
}
```
And to build/load the resulting image:  
`nix build .#caligaConfigurations.x86_64-linux.myimage.config.build.image && ./result | podman load`

## Going forwards

- Tests
- Keep an eye on system-manager and bring over useful features.
- Sops-nix and hopefully [Vars](https://clan.lol/blog/vars/).
- Importing more nixos services
- Networking (watching to see how system-manager will handle this)
- Maybe a caliga-cli tool
- Create a separate nix-caliga based kiosk configuration and set of images. (The original reason I went down this rabbit hole.)


## LLM/AI usage note
Language models are being used as a tool in the development of Nix-caliga.  
Everything is writen/designed by human hands using the assistance of language models to speed up work.
