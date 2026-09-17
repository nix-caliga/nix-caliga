# nix and nix daemon with a writable /nix overlay
{
  config,
  lib,
  pkgs,
  nixpkgs,
  utils,
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

  lowerStoreUrl = "/run/nix-lower?read-only=true";
  localOverlayStoreUrl = "local-overlay://?upper-layer=/var/nix/store/upper&state=/var/nix/overlay-state&lower-store=${lowerStoreUrl}";
  nixEnv = {
    NIX_DAEMON_SOCKET_PATH = "/nix/var/nix/daemon-socket/socket";
    NIX_LOG_DIR = "/var/nix/var/log/nix";
    NIX_STATE_DIR = "/var/nix/overlay-state";
  };
in
{
  options.nix = {
    enable = lib.mkEnableOption "Nix package manager and daemon using a local-overlay-store on top of the image's built in nix store.";
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
        experimental-features = [
          "nix-command"
          "flakes"
          "local-overlay-store"
          "read-only-local-store"
        ];
        nix-path = "nixpkgs=${nixpkgs}";
        store = "daemon";
      };
      description = ''
        Settings written to /etc/nix/nix.conf. Defaults to enabling
        nix-command, flakes, local-overlay-store, and
        read-only-local-store, pointing nix-path at the nixpkgs source
        baked into the image from the flake input, and configuring the
        store as a local-overlay-store layered over the image-baked
        /nix
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

    environment.variables = nixEnv;
    systemd.globalEnvironment = nixEnv;

    systemd.mounts = [
      {
        where = "/run/nix-lower/nix";
        what = "/nix";
        options = "bind,ro";
        after = [ "ostree-remount.service" ];
        wants = [ "ostree-remount.service" ];
        unitConfig.DefaultDependencies = false;
      }
      {
        where = "/nix/store";
        what = "overlay";
        type = "overlay";
        options = "lowerdir=/run/nix-lower/nix/store,upperdir=/var/nix/store/upper,workdir=/var/nix/store/work";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        after = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        requires = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
          ConditionPathIsReadWrite = "!/nix/store";
        };
      }
      # makes sure the image's gcroots are always fresh
      {
        where = "/var/nix/overlay-state/gcroots/docker";
        what = "/run/nix-lower/nix/var/nix/gcroots/docker";
        options = "bind,ro";
        after = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        requires = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
        };
      }
      {
        where = "/nix/var/nix";
        what = "tmpfs";
        type = "tmpfs";
        options = "mode=0755";
        unitConfig = {
          DefaultDependencies = false;
          ConditionPathIsReadWrite = "!/nix/var/nix";
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/nix/store/upper 0755 root root -"
      "d /var/nix/store/work 0755 root root -"
      "d /var/nix/overlay-state/gcroots 0755 root root -"
      "d /var/nix/overlay-state/db 0755 root root -"
      "d /var/nix/overlay-state/profiles 0755 root root -"
      "d /var/nix/overlay-state/temproots 0755 root root -"
      "d /var/nix/overlay-state/userpool 0755 root root -"
    ];

    systemd.services.nix-daemon-socket-setup = {
      requires = [ "${utils.escapeSystemdPath "/nix/var/nix"}.mount" ];
      after = [
        "${utils.escapeSystemdPath "/nix/var/nix"}.mount"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -dm 0755 /nix/var/nix/daemon-socket
      '';
    };

    systemd.sockets.nix-daemon = {
      wantedBy = [ "sockets.target" ];
      requires = [ "nix-daemon-socket-setup.service" ];
      after = [ "nix-daemon-socket-setup.service" ];
    };

    systemd.services.nix-daemon = {
      serviceConfig.ExecStart = [
        ""
        "@${cfg.package}/bin/nix-daemon nix-daemon --daemon --option store ${localOverlayStoreUrl}"
      ];
      requires = [ "${utils.escapeSystemdPath "/var/nix/overlay-state/gcroots/docker"}.mount" ];
      after = [ "${utils.escapeSystemdPath "/var/nix/overlay-state/gcroots/docker"}.mount" ];
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
      lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${formatValue v}") cfg.settings)
      + "\n";
  };
}
