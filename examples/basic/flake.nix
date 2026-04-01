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
