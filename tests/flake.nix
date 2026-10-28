{
  description = "Test runners with nightly-refreshed base image pins";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    root.url = "path:../.";
    bootc-image-prefetcher.url = "github:nix-caliga/bootc-image-prefetcher";
  };

  outputs =
    {
      nixpkgs,
      root,
      bootc-image-prefetcher,
      ...
    }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      tests = import ./default.nix {
        inherit pkgs;
        self = root;
        fromImage = pkgs.dockerTools.pullImage bootc-image-prefetcher.pins.fedora-bootc."44";
      };
    in
    {
      packages.x86_64-linux = tests.packages;
      apps.x86_64-linux = tests.apps;
    };
}
