# firewall module - nftables-based firewall using upstream nixpkgs modules
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    "${pkgs.path}/nixos/modules/services/networking/firewall.nix"
    "${pkgs.path}/nixos/modules/services/networking/nftables.nix"
    "${pkgs.path}/nixos/modules/services/networking/firewall-nftables.nix"
  ];

  config = {
    networking.nftables.checkRuleset = lib.mkDefault false;
  };

  options = {
    services.firewalld.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    networking.firewall.extraCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    networking.firewall.extraStopCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    systemd.additionalUpstreamSystemUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    boot.kernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    boot.extraModprobeConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    boot.blacklistedKernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
}
