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

  lowerRoot = "/nix";
  lowerStoreReal = "${lowerRoot}/store";
  lowerStoreState = "${lowerRoot}/var/nix";
  lowerStoreUri =
    "local://?real=${lowerStoreReal}&state=${lowerStoreState}&read-only=true";
  upperRoot = "/var/nix";
  upperLayer = "${upperRoot}/upper";
  upperWorkDir = "${upperRoot}/work";
  upperStoreState = "${upperRoot}/var/nix";
  nixEnv = {
    NIX_DAEMON_SOCKET_PATH = "${upperStoreState}/daemon-socket/socket";
    NIX_LOG_DIR = "${upperRoot}/var/log/nix";
    NIX_STATE_DIR = upperStoreState;
  };

  formatValue =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isList v then
      lib.concatMapStringsSep " " toString v
    else
      toString v;
in
{
  options.nix = {
    enable = lib.mkEnableOption "Nix package manager and daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
      description = "The Nix package to use.";
    };
    nrBuildUsers = lib.mkOption {
      type = lib.types.int;
      default = 32;
      description = "Number of Nix build users to create.";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        store =
          "local-overlay://?lower-store=${lib.strings.escapeURL lowerStoreUri}"
          + "&upper-layer=${lib.strings.escapeURL upperLayer}"
          + "&state=${lib.strings.escapeURL upperStoreState}";
        experimental-features = [
          "nix-command"
          "flakes"
          "local-overlay-store"
          "read-only-local-store"
        ];
        # considering adding this with a systemd service so nixpkgs source doesnt get built into the image, thinking it might heavily contribute to ostree xattrs hard link limits?
        nix-path = "nixpkgs=${nixpkgs}";
      };
      description = ''
        Settings written to /etc/nix/nix.conf. Defaults to enabling
        nix-command, flakes, and pointing nix-path at the nixpkgs
        source baked into the image from the flake input.
      '';
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

    systemd.sockets.nix-daemon = {
        wantedBy = [ "sockets.target" ];
        requires = ["nix-directory-setup.service"];
        after = ["nix-directory-setup.service"];
        unitConfig.ConditionPathIsReadWrite = [ "" upperStoreState ];
        socketConfig = {
            ListenStream = [ "" "${upperStoreState}/daemon-socket/socket" ];
            SocketMode = "0666";
        };
    };

    systemd.services.nix-daemon = {
        requires = ["nix-directory-setup.service"];
        after = ["nix-directory-setup.service"];
        unitConfig.ConditionPathIsReadWrite = [ "" upperStoreState ];
    };

    environment.variables = nixEnv;
    systemd.globalEnvironment = nixEnv;

    # writable /nix over read-only image /nix.
    # Skipped in containers where /nix is already writable.
    systemd.mounts = [
      {
        where = "${lowerStoreReal}";
        what = "overlay";
        type = "overlay";
        options = "lowerdir=${lowerStoreReal},upperdir=${upperLayer},workdir=${upperWorkDir}";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        requires = ["nix-directory-setup.service"];
        after = ["nix-directory-setup.service"];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
          ConditionPathIsReadWrite = "!${lowerStoreReal}";
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${upperRoot} 0755 root root -"
      "d ${upperLayer} 0755 root root -"
      "d ${upperWorkDir} 0755 root root -"
    ];

    systemd.services.nix-directory-setup = {
      description = "Create Nix daemon directories";
	  after = [ "local-fs.target" ];
      before = [
        "nix-store.mount"
        "nix-daemon.socket"
        "nix-daemon.service"
      ];
      wantedBy = [ "sockets.target" ];
      unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -dm 0755 \
          ${upperStoreState}/{db,daemon-socket,gcroots,profiles,temproots,userpool} \
          ${upperRoot} ${upperLayer} ${upperWorkDir}
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
      lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${formatValue v}") cfg.settings) + "\n";
  };
}
