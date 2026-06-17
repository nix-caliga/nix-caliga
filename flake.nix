{
  description = "Configuring bootc images with nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      imageConfigs = {
        fedora-bootc = ./images/fedora-bootc;
        fedora-base-atomic = ./images/fedora-base-atomic;
        fedora-silverblue = ./images/fedora-silverblue;
        fedora-kinoite = ./images/fedora-kinoite;
        ublue-base-main = ./images/ublue-base-main;
        ublue-silverblue-main = ./images/ublue-silverblue-main;
        ublue-kinoite-main = ./images/ublue-kinoite-main;
        ublue-aurora = ./images/ublue-aurora;
        ublue-bazzite = ./images/ublue-bazzite;
        ublue-bluefin = ./images/ublue-bluefin;
        ublue-ucore = ./images/ublue-ucore;
        ublue-bluefin-dakota = ./images/ublue-bluefin-dakota;
      };
    in
    {
      lib = import ./lib { inherit nixpkgs; };

      inherit imageConfigs;

      modules.default = ./modules;

      caligaConfigurations.x86_64-linux = builtins.mapAttrs (
        _: configPath:
        self.lib.makeCaligaConfigurations {
          inherit pkgs;
          modules = [ configPath ];
        }
      ) imageConfigs;

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.podman
          pkgs.gh
          pkgs.jq
          pkgs.nixfmt
          pkgs.nixfmt-tree
          pkgs.nix-prefetch-docker
        ];
      };
    };
}
