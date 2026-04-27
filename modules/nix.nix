# nix and nix daemon with a writable /nix overlay
{
  config,
  lib,
  pkgs,
  nixpkgs,
  ...
}:

let
  cfg = config.nix;

  formatValue =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isList v then
      lib.concatMapStringsSep " " toString v
    else
      toString v;

  allSettings = {
    build-users-group = "nixbld";
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix-path = "nixpkgs=${nixpkgs}";
  }
  // cfg.settings;
in
{
  options.nix = {
    enable = lib.mkEnableOption "Nix package manager and daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
    };
    nrBuildUsers = lib.mkOption {
      type = lib.types.int;
      default = 32;
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.caliga.core.etc-usr.enable;
        message = "nix.enable requires caliga.core.etc-usr.enable = true";
      }
      {
        assertion = config.caliga.core.systemd.enable;
        message = "nix.enable requires caliga.core.systemd.enable = true";
      }
      {
        assertion = config.caliga.core.tmpfiles.enable;
        message = "nix.enable requires caliga.core.tmpfiles.enable = true";
      }
      {
        assertion = config.caliga.core.users.enable;
        message = "nix.enable requires caliga.core.users.enable = true";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # include the nix db from the layeredImage.contents so the nix daemon can see it
    layeredImage.includeNixDB = true;

    # Pick up nix-daemon.service, nix-daemon.socket, tmpfiles
    systemd.packages = [ cfg.package ];
    systemd.tmpfiles.packages = [ cfg.package ];

    systemd.sockets.nix-daemon.wantedBy = [ "sockets.target" ];

    # writable /nix over read-only image /nix.
    # Skipped in containers where /nix is already writable.
    systemd.mounts = [
      {
        where = "/nix";
        what = "overlay";
        type = "overlay";
        options = "lowerdir=/nix,upperdir=/var/nix/upper,workdir=/var/nix/work";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
          ConditionPathIsReadWrite = "!/nix";
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/nix 0755 root root -"
      "d /var/nix/upper 0755 root root -"
      "d /var/nix/work 0755 root root -"
    ];

    systemd.services.nix-directory-setup = {
      description = "Create Nix daemon directories";
      after = [
        "nix.mount"
        "local-fs.target"
      ];
      before = [ "nix-daemon.socket" ];
      wantedBy = [ "sockets.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /nix/var/nix/{db,daemon-socket,gcroots,profiles,temproots,userpool}
      '';
    };

    users.groups.nixbld.gid = 30000;
    users.users = lib.listToAttrs (
      map (i: {
        name = "nixbld${toString i}";
        value = {
          isSystemUser = true;
          uid = 30000 + i;
          group = "nixbld";
          extraGroups = [ "nixbld" ];
          description = "Nix build user ${toString i}";
        };
      }) (lib.range 1 cfg.nrBuildUsers)
    );

    environment.etc."nix/nix.conf".text =
      lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${formatValue v}") allSettings) + "\n";
  };
}
