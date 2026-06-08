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
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems f;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
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

      caligaConfigurations = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        builtins.mapAttrs (
          _: configPath:
          self.lib.makeCaligaConfigurations {
            inherit pkgs;
            modules = [ configPath ];
          }
        ) imageConfigs
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          caliga = self.lib.mkCaligaCli {
            inherit pkgs;
            caligaConfigurations = self.caligaConfigurations.${system};
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.podman
              pkgs.gh
              pkgs.jq
              pkgs.nixfmt
              pkgs.nixfmt-tree
              pkgs.nix-prefetch-docker
              caliga
            ];
            shellHook = ''
              source ${caliga}/share/bash-completion/completions/caliga
            '';
          };
        }
      );
    };
}
