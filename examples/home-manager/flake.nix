{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "github:nix-caliga/nix-caliga";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-caliga,
      home-manager,
      ...
    }:
    {
      caligaConfigurations.x86_64-linux = {
        myimage = nix-caliga.lib.makeCaligaConfigurations {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            home-manager.nixosModules.home-manager
            ./images/myimage
          ];
        };
      };
    };
}
