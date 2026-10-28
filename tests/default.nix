# runner: packages.x86_64-linux.<name>
# tests: apps.x86_64-linux.<name> (nix run .#<name>)
{ pkgs, self, fromImage ? null }:
let
  lib = pkgs.lib;
  images = import ./lib/images.nix { inherit pkgs lib self; };
  runner = import ./lib/runner.nix { inherit pkgs lib; };

  configs = {
    base = [ ./configs/base.nix ];
  };

  runners = lib.mapAttrs (
    name: modules:
    runner.mkRunner {
      inherit name;
      image = images.mkImage { inherit name modules fromImage; };
      testFile = "${name}.bats";
    }
  ) configs;
in
{
  inherit configs runners;
  packages = runners;
  apps = lib.mapAttrs (name: runner: {
    type = "app";
    program = "${runner}/bin/caliga-test-${name}";
  }) runners;
}
