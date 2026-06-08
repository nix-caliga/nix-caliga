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
    }:
    let
      lib = pkgs.lib;

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
        specialArgs = {
          inherit pkgs;
        };
      };

      cfg = evaluated.config;

      failedAssertions = map (x: x.message) (lib.filter (x: !x.assertion) cfg.assertions);
    in
    if failedAssertions != [ ] then
      throw "\nFailed assertions:\n${lib.concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}"
    else
      lib.showWarnings cfg.warnings evaluated;
}
