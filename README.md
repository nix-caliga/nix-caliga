<div align="center">

# Nix-caliga
Snow boot(c)

</div>

<br>

Nix-caliga aims to be to bootc images what [system-manager](https://github.com/numtide/system-manager) and [nix-darwin](https://github.com/nix-community/nix-darwin) are to Linux and macOS.

Using NixOS-like configuration, nix-caliga builds `pkgs.dockerTools.streamLayeredImage` outputs designed for bootc images.
This provides modularity to bootc image creation and access to nixpkgs.

## Why nix-caliga?

[BlueBuild](https://blue-build.org/) Is a set of tools for modular recipes that assemble bootc Containerfiles. Being familiar with NixOS, I wanted additional control over the configuration along with the package diversity and dependency management from nixpkgs.

This also provides a few additional benefits over standard NixOS:
- *It's NOT NixOS.* Providing options for:
  - POSIX-compatiblility
  - SELinux
  - Secure Boot (by default)
- Increased package availability. Some software is extremely unlikely to make it into nixpkgs for various reasons, but often has official support for mainline Linux distributions, which you can make use of with a base bootc image.
- Configuring bootc images with nix-caliga does not stop traditional oci image workflows from being useful alongside it.

In my experience with NixOS, its strength isn't the fact that it is NixOS. It's the reliability, reproducibility, and modularity.
Nix-caliga aims to keep these strengths while being more flexible and compatible with the growing bootc toolset.

## Current features

> Currently in the very early stages.  
> Heavily based on numtide's [system-manager](https://github.com/numtide/system-manager), with the majority of modules copied directly from it and adjusted to work with bootc image layering.

- Systemd configuration through familiar NixOS-based `systemd` options.
- File creation/placement through NixOS-based `environment.etc` and `systemd.tmpfiles` options.
- User/group creation and management with NixOS-based `users.users` options, powered by userborn (as [system-manager](https://github.com/numtide/system-manager) does).
- Automatic bootc update management with optional authentication.
- Experimental SELinux configuration and default labels for Nix store paths.
- Nix packages to $PATH with `environment.systemPackages`
- Testing against Fedora's bootc images.

## Going forwards

- Documentation
- Tests
- Expand to ublue's "distroless" bootc image ([dakota](https://github.com/projectbluefin/dakota)) as it becomes stable.
- Keep an eye on system-manager and bring over useful features.
- Secret management, hopefully with [Vars](https://clan.lol/blog/vars/).
- Importing more nixos services
- Networking (watching to see how system-manager will handle this)
- Create a separate nix-caliga based kiosk configuration and set of images. (The original reason I went down this rabbit hole.)


## Caliga-cli
Commands for development/testing that are flake-aware with tab completion


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

  outputs = { self, nixpkgs, nix-caliga }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      caligaConfigs = {
        myimage = nix-caliga.lib.makeCaligaConfig {
          inherit pkgs;
          modules = [ ./images/myimage ];
        };
      };
      caliga = nix-caliga.lib.mkCaligaCli { inherit pkgs caligaConfigs; };
    in
    {
      caligaConfigs.${system} = caligaConfigs;

      devShells.${system}.default = pkgs.mkShell {
        packages = [ caliga ];
        shellHook = ''
          source ${caliga}/share/bash-completion/completions/caliga
        '';
      };
    };
}
```

And an example caligaConfig
Check `pkgs.dockerTools.pullImage` documentation to setup the `fromImage`
```nix
{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "test";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:850575ab43ae474135fa91dbf10b3a208ceaf0168158cff45fe2b37d2ee11fe9";
      sha256 = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
      finalImageTag = "43";
    };
  };

  users.users.test1 = {
    isNormalUser = true;
    uid = 1001;
    description = "Test User";
    initialPassword = "test";
  };

  system.stateVersion = "25.11";

  services.bootc-update = {
    enable = true;
    schedule = {
      onBootSec = "20s";
      onUnitActiveSec = "20s";
    };
  };

  systemd.maskedUnits = [
    "sleep.target"
  ];
}
```
