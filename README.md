<div align="center">

# Nix-caliga
Snow boot(c)

</div>

<br>

Nix-caliga aims to be to bootc images what [system-manager](https://github.com/numtide/system-manager) and [nix-darwin](https://github.com/nix-community/nix-darwin) are to Linux and macOS.

Using NixOS-like configuration, nix-caliga builds `pkgs.dockerTools.streamLayeredImage` outputs to configure bootc images.

## Current features

> Currently in the very early stages.  
> Heavily based on numtide's [system-manager](https://github.com/numtide/system-manager), with a number of modules copied directly from it and adjusted to work with bootc image layering.

- Systemd configuration through familiar NixOS-based `systemd` options.
- File creation/placement through NixOS-based `environment.etc`, `environment.usr` and `systemd.tmpfiles` options.
- User/group creation and management with NixOS-based `users.users` options, powered by userborn (as [system-manager](https://github.com/numtide/system-manager) does).
- Automatic bootc update management with optional authentication.
- SELinux configuration and default labels for Nix store paths.
- Nix-daemon, not required for nix-caliga images, but is an optional service you can enable
- Nix packages to $PATH with `environment.systemPackages`
- Bootc's ostree-prepare-root configuration at `bootc.ostree-prepare-root`
- Optional nix configured containerfile to handle tasks streamLayeredImage can't (rebuild initramfs etc)
- Testing against Fedora's bootc images, and expanding to ublue and projectbluefin/dakota images.

All modules are disabled by default, and you opt in to the parts of nix-caliga you need.

## Tested images

Fedora-bootc is the primary image that I am working with and is the focus. Thankfully most common bootc images are also based on Fedora.  
I have done minimal testing with these other bootc images. Testing on a fresh VM I have confirmed:
- SELinux
- User creation
- Systemd services
- Etc/usr and tmpfile creation
- Regen'ing initramfs to setup a tranisent etc via caliga.core.containerfile  

Are all working. So far I have not tested on bare metal, or with an updating system.

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
| [ublue-bluefin-dakota](https://github.com/projectbluefin/dakota) | `gnomeOS` | Configures initramfs differently, Initramfs regen doesnt work. |

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

- Proper tests
- Keep an eye on system-manager and bring over useful features.
- Secret management, with Agenix, Sops-nix and hopefully [Vars](https://clan.lol/blog/vars/).
- Home-manager 
- Importing more nixos services
- Networking (watching to see how system-manager will handle this)
- Fully design a caliga-cli tool
- Create a separate nix-caliga based kiosk configuration and set of images. (The original reason I went down this rabbit hole.)


## LLM/AI usage note
Language models are being used as a tool in the development of Nix-caliga.  
The nix modules are being writen/designed by human hands using the assistance of language models to speed up work.

Documentation is writen by a human as well.

Currently the caliga-cli and tests are pretty much raw vibes. I am not sure what I want these to look like long term, and are currently just tools to help me in testing/developing Nix-caliga while I work out what I need them to be.  
I would not recommend using/relying on the caliga-cli or tests under /tests unless you review the code for them yourself.

The rest of the code (The nix modules themselves) are in a state where the code matches my own human ability.
