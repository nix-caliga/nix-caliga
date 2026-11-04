{
  pkgs,
  lib,
  self,
}:
{
  mkImage =
    { name, modules }:
    let
      eval = self.lib.makeCaligaConfigurations {
        inherit pkgs;
        modules = modules ++ [
          {
            layeredImage.name = "localhost/caliga-tests";
            layeredImage.tag = name;
          }
        ];
      };
    in
    eval.config.build.image;
}
