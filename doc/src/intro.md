# What is Nix-caliga
Nix-caliga is a tool to use the nix language to configure bootc images similarly to how you would configure NixOS. Sharing identical options, and using upstream NixOS modules where possible.  
Heavily inspired by numtide's system-manager significant chunks of nix-caliga uses their works.  
Nix-caliga is currently in its early stages and likely making a number of breaking changes.

Example of a caligaConfiguration:
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

## Nix-Caliga vs NixOS
Because Nix-caliga is able to build on top of more traditional OS bootc images as a base, we gain a number of benefits. (If supported by the chosen base image)
* POSIX compatablility
* SELinux 
* Secure boot out of the box 
* Supports applications nixpkgs struggles to package, but that often have first party support in traditional OS repositories.    

Additonally, Nix-caliga doesn't lock the system down to one tool, and can be used along side other existing bootc workflows and tools.  
For example, an expected use case scenario would be to take a base image built by another team. Maybe they built it with standard containerfiles, BlueBuild, or BuildStream. Then you use Nix-caliga on top of their image to customize to your use case(s), before finishing up with a final containerfile to rebuild the initramfs, and install a couple base-image specific packages.  

NixOS has a number of strong advantages, such as the **full** system being build by nix. But Nix-caliga should be able to bring the power of Nix to more places.

## Nix-Caliga vs "Traditional" Bootc Tools

### Nix Language
There are a number of discussions online comparing nix to yaml/containerfile/toml/json/etc and I won't dive into it here. Nix(language) is not perfect, but it offers significantly more power over yaml.  
Different tools will be better suited to different usecases. Nix-caliga expands the tools available for the job.

### Nix Ecosystem
Nix-caliga can also support other Nix based projects like Agenix for secrets, Home-manager for user environments and desktop configuration, and Microvm.nix for NixOS based microvms. All are working/testing in progress.  
Sops-nix, Vars, Comma and others will hopefully be setup soon too.

### Cross Configuration
Bootc images can share configuration, including identical package updates, alongside NixOS based systems. Allowing for more flexibility and less duplicated configuration across systems.

## How It Works
This project is built on [nixpkgs.dockerTools' streamLayeredImage](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-streamLayeredImage) which "builds a script which, when run, will stream to stdout a Docker-compatible repository tarball containing a single image, using multiple layers to improve sharing between images."  
Using `streamLayeredImage`, with a handful of modules, allows us to configure oci images, specifically bootc images, similarly to how we would configure nixos.  
Base images in testing right now are Fedora and a handful of uBlue images including the new projectbluefin/dakota image based off of GnomeOS.  
The result is a configured image that does not require a nix-package, or a nix-daemon. Both are available to be included if desired, but are not required and disabled by default.

Where possible we use `streamLayeredImage.contents` to deliver the configuration as symlinks to the image's nix store. If the nix-daemon is enabled, the nix db for the image contents is included for the nix-daemon.  
At times, symlinks don't cut it and we use `streamLayeredImage.fakeRootCommands` to copy files into place with required permissions.

Optionally there is a nix configured containerfile that podman will run after `streamLayeredImage`. Allowing for some workflows such as rebuilding the initramfs, that aren't available with `streamLayeredImage` alone. This is disabled by default, and can be handled by external workflows if desired.
