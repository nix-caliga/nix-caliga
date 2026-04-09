{
  description = "Configuring bootc images with nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    userborn = {
      url = "github:jfroche/userborn/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      userborn,
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
        test = ./images/test;
      };
    in
    {
      lib = import ./lib { inherit userborn nixpkgs; };

      inherit imageConfigs;

      modules.default = ./modules;

      caligaConfigs = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        builtins.mapAttrs (
          _: configPath:
          self.lib.makeCaligaConfig {
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
            caligaConfigs = self.caligaConfigs.${system};
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
