{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "path:../..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-caliga,
      agenix,
      ...
    }:
    {
      caligaConfigurations.x86_64-linux = {
        myimage = nix-caliga.lib.makeCaligaConfigurations {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            agenix.nixosModules.default
            ./images/myimage
          ];
        };
      };
    };
}
