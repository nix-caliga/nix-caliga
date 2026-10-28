{
  pkgs,
  lib,
  self,
}:
{
  mkImage =
    { name, modules, fromImage ? null }:
    let
      eval = self.lib.makeCaligaConfigurations {
        inherit pkgs;
        modules = modules ++ [
          {
            layeredImage.name = "localhost/caliga-tests";
            layeredImage.tag = name;
          }
        ] ++ lib.optional (fromImage != null) { layeredImage = { inherit fromImage; }; };
      };
    in
    eval.config.build.image;
}
