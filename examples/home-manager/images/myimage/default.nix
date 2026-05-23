{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/yomaq/nix-config";
    tag = "cyan";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/projectbluefin/dakota";
      imageDigest = "sha256:1876990f38722642c241e2a765022984e87f8df1ef29a05aa4bd5f63f30cb924";
      hash = "sha256-C/tbOfuR/QP09qqvf3IrxjAj/Wj0WJsZbAQ9S6x9lJo=";
      finalImageTag = "latest";
    };
  };

  caliga.os = "gnomeOS";
  caliga.core.enable = true;
  system.stateVersion = "25.11";

  users.users.test = {
    isNormalUser = true;
    uid = 1008;
    description = "Example User";
    initialPassword = "password";
  };

  nix.enable = true;

  environment.systemPackages = [pkgs.cowsay];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.test = {
    home.stateVersion = "25.11";
    home.packages = [ pkgs.alacritty ];
    programs = {
      git = {
        enable = true;
        settings.user = {
          name = "Example User";
          email = "user@example.com";
        };
      };
      alacritty = {
        enable = true;
        settings = {
          window = {
            opacity = 0.8;
            decorations = "None";
          };
        };
      };
    };
  };
}
