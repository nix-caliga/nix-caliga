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

  outputs = inputs: {
    caligaConfigurations.x86_64-linux = {
      myimage = inputs.nix-caliga.lib.makeCaligaConfigurations {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        specialArgs = { inherit inputs; };
        modules = [ ./images/myimage ];
      };
    };
  };
}
