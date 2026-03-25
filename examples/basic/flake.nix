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
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      caliga = nix-caliga.lib.mkCaligaCli { inherit pkgs; caligaConfigs = self.caligaConfigs; };
    in
    {
      caligaConfigs = {
        myimage = nix-caliga.lib.makeCaligaConfig {
          inherit pkgs;
          modules = [ ./images/myimage ];
        };
      };

      packages.x86_64-linux = self.caligaConfigs;

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ caliga ];
        shellHook = ''
          source ${caliga}/share/bash-completion/completions/caliga
        '';
      };
    };
}
