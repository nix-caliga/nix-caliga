{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "github:nix-caliga/nix-caliga";
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
      ...
    } @ inputs:
    {
      caligaConfigurations.x86_64-linux = {
        myimage = nix-caliga.lib.makeCaligaConfigurations {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          specialArgs = { inherit inputs; };
          modules = [ ./images/myimage ];
        };
      };
    };
}
