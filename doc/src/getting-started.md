# Getting Started

## Flake.nix setup

To get started you'll need a flake.nix file that looks something like this:

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
        myimage = nix-caliga.lib.makeCaligaConfig {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [ ./images/myimage ];
        };
      };
    };
}
```
Edit the name `myimage` as you like, and the path `./images/myimage` to match the path the image configuration you make below.  

## Image hash

First, pickout which base image you want to use. See [Setting Base Image OS](caliga.md) for a list of base images currently in testing.  
Then you'll want to prefetch the bootc image hash. You can use `nix-prefetch-docker` for this:
```sh
nix run nixpkgs#nix-prefetch-docker -- --image-name quay.io/fedora/fedora-bootc --image-tag 43
```
Output will look something like:
```
{
  imageName = "quay.io/fedora/fedora-bootc";
  imageDigest = "sha256:e71dcfa52627f5b3d6da939639b56add0b5787536372d1d2e7684ce282c5573b";
  hash = "sha256-ZUBcjt3GV7GNU7K+shkfC5uxeHwKdHxemOBaiwe4CRI=";
  finalImageName = "quay.io/fedora/fedora-bootc";
  finalImageTag = "43";
}
```

## Image Configuration

A full file example is at the end, you can also look at the project's `examples/` folder.  
Start by filling in the image information from nix-prefetch-docker.

```nix
{ pkgs, ... }:

{
  config = {
    layeredImage = {
      # This is the name of the resulting image you make
      name = "ghcr.io/nix-caliga/nix-caliga";
      # This is the tag of the resulting image you make
      tag = "tag";
      fromImage = pkgs.dockerTools.pullImage {
        # These come from nix-prefetch-docker
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:9d7a12d886dd2a50589d141b3d71d5dad520b3e131680356dccd484bc171e03e";
        hash = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
        finalImageTag = "43";
      };
    };
  };
}
```

Nix-caliga makes no changes by default, so you need to select what [modules](caliga.md) you need.  
I recommend starting with `config.caliga.core.enable = true` to enable all core modules, as well as setting `config.caliga.os` to your base image's OS.  
I also recommend setting the current NixOS version for the state version.  

```nix
{ pkgs, ... }:
{
  config = {
    
    ...
    # set your base image OS
    caliga.os = "fedora";
    # this enables all core modules for nix-caliga
    caliga.core.enable = true;
    # set the current nixos version
    system.stateVersion = "25.11";
  };
}
```

Now you can start adding configuration, such as a [user account](users-groups.md), and maybe some nixpkgs you want available.  
To configure systemd service, take a look [here](systemd.md). They are configured the same as systemd on NixOS.

```nix
{ pkgs, ... }:

{
  config = {
    
    ...
    # set your username
    users.users.yourUser = {
      isNormalUser = true;
      uid = 1001;
      description = "Example User";
      # This will set your password at first login, it can be changed afterward
      initialPassword = "password";
    };

    # a list of nixpkgs you want available to all users
    environment.systemPackages = [ 
      pkgs.cowsay
      pkgs.nixfmt
    ];
  };
}
```

### Full Example Image Config

```nix
{ pkgs, ... }:

{
  config = {
    layeredImage = {
      # This is the name of the resulting image you make
      name = "ghcr.io/nix-caliga/nix-caliga";
      # This is the tag of the resulting image you make
      tag = "tag";
      fromImage = pkgs.dockerTools.pullImage {
        # These come from nix-prefetch-docker
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:9d7a12d886dd2a50589d141b3d71d5dad520b3e131680356dccd484bc171e03e";
        hash = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
        finalImageTag = "43";
      };
    };

    # set your base image OS
    caliga.os = "fedora";
    # this enables all core modules for nix-caliga
    caliga.core.enable = true;
    # set the current nixos version
    system.stateVersion = "25.11";

    # set your username
    users.users.yourUser = {
      isNormalUser = true;
      uid = 1001;
      description = "Example User";
      # This will set your password at first login, it can be changed afterward
      initialPassword = "password";
    };

    # a list of nixpkgs you want available to all users
    environment.systemPackages = [
      pkgs.cowsay
      pkgs.nixfmt
    ];
  };
}
```

## Building the Image

Build and load the resulting image:

```sh
nix build .#caligaConfigurations.x86_64-linux.myimage.config.build.image && ./result | podman load
```

## Using the Image

You can test the image as a container with podman, replace the image name with your newly created image.

```sh
podman run -it --rm ghcr.io/nix-caliga/nix-caliga:tag
```

To install the image to a disk or VM, use [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) which can make a bunch of different disk image formats from your bootc image.  
For more information on working with bootc images, see the [bootc documentation](https://bootc.dev/).
