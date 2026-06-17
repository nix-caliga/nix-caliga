{
  nixpkgs,
}:
{
  mkCaligaCli =
    { pkgs, caligaConfigurations }:
    import ../dev/caliga-cli.nix {
      inherit pkgs caligaConfigurations;
    };

  makeCaligaConfigurations =
    {
      modules,
      pkgs,
      lib ? pkgs.lib,
      specialArgs ? { },
    }:
    let

      extraArgsModule =
        { config, ... }:
        {
          _module.args = {
            inherit nixpkgs;
            utils = import "${pkgs.path}/nixos/lib/utils.nix" {
              inherit lib config pkgs;
            };
          };
        };

      evaluated = lib.evalModules {
        modules = [
          extraArgsModule
          ../modules
        ]
        ++ modules;
        specialArgs = { inherit pkgs; } // specialArgs;
      };

      cfg = evaluated.config;
    in
    lib.asserts.checkAssertWarn cfg.assertions cfg.warnings evaluated;
}
