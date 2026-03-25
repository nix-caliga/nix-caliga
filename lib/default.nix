{
  userborn,
}:
{
  mkCaligaCli = { pkgs, caligaConfigs }: import ../dev/caliga-cli.nix { inherit pkgs caligaConfigs; };

  makeCaligaConfig =
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
            userborn = userborn.packages.${pkgs.stdenv.hostPlatform.system}.default;
            utils =
              let
                nixosUtils = import "${pkgs.path}/nixos/lib/utils.nix" {
                  inherit lib config pkgs;
                };
              in
              nixosUtils
              // {
                toShellPath =
                  shell:
                  if lib.types.shellPackage.check shell then
                    "${shell}${shell.shellPath}"
                  else if lib.types.package.check shell then
                    throw "${shell} is not a shell package"
                  else
                    shell;
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

      image = pkgs.dockerTools.streamLayeredImage cfg.build.imageArgs;
    in
    if failedAssertions != [ ] then
      throw "\nFailed assertions:\n${lib.concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}"
    else
      lib.showWarnings cfg.warnings image;
}
