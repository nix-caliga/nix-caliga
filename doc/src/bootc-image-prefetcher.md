# bootc-image-prefetcher

Updating the base image hashes manually gives a lot of control, but can be annoying.
[bootc-image-prefetcher](https://github.com/nix-caliga/bootc-image-prefetcher) checks for updates every night, and can update your project as you update your lockfile.

Add it as a flake input alongside nix-caliga:

```nix
inputs.bootc-image-prefetcher.url = "github:nix-caliga/bootc-image-prefetcher";
```

Then in your image config, use a pin as `layeredImage.fromImage`.
The image names are the name of the directories within /pin, and the tag is the name of the file.
`bootc-image-prefetcher.pins.<imageName>."<tag>"`

```nix
{ inputs, pkgs, ... }:
{
  layeredImage.fromImage = pkgs.dockerTools.pullImage inputs.bootc-image-prefetcher.pins.fedora-base-atomic."44";
}
```

See the full example: [examples/bootc-image-prefetcher/](https://github.com/nix-caliga/nix-caliga/tree/main/examples/bootc-image-prefetcher).

To adjust which images and tags are pinned, I recommend forking and configuring [`updater/images.nix`](https://github.com/nix-caliga/bootc-image-prefetcher/blob/main/updater/images.nix) with the images you want to have auto-update.
