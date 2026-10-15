# nix and nix daemon with a local-overlay-store on top of the image's nix store
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nix;

  # https://github.com/NixOS/nix/blob/2.34.7/tests/functional/local-overlay-store/common.sh#L7-L28
  # https://github.com/NixOS/nix/blob/2.34.7/tests/functional/local-overlay-store/remount.sh#L2
  remountHook = pkgs.writeShellScript "nix-store-remount" ''
    LIBMOUNT_FORCE_MOUNT2=always ${pkgs.util-linux}/bin/mount -o remount "$1"
  '';
  localOverlayStoreUrl = "local-overlay://?upper-layer=/var/nix/store/upper&lower-store=/run/nix-lower?read-only=true&remount-hook=${remountHook}";

  # for verifying if the image's store changed
  writeStamp = ''
    LC_ALL=C ls -1 /run/nix-lower/nix/var/nix/gcroots/docker > /var/nix/lower-store-roots
    rm -f /run/nix-lower-store-changed
  '';
  # delete upper store and reset
  resetUpper = ''
    rm -rf /var/nix/store/upper /var/nix/store/work /var/nix/var
    # user profiles need to be handled as well
    cut -d: -f6 /etc/passwd | while read -r home; do rm -rf "$home/.local/state/nix/profiles"; done
    /usr/bin/systemd-tmpfiles --create --prefix=/var/nix
    ${writeStamp}
  '';
in
{
  options.nix = {
    enable = lib.mkEnableOption "Nix package manager and daemon using a local-overlay-store on top of the image's built in nix store. Be sure to review `config.nix.onImageChange`.";
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
      type = lib.types.submodule {
        # same as NixOS nix.settings, lists merge across definitions
        # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/nix.nix#L63-L79
        freeformType =
          with lib.types;
          let
            confAtom = nullOr (oneOf [
              bool
              int
              float
              str
              path
              package
            ]);
          in
          attrsOf (either confAtom (listOf confAtom));
        options.experimental-features = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "nix-command"
            "flakes"
          ];
          description = ''
            Experimental features to enable.
            local-overlay-store and read-only-local-store are always enabled regardless of this setting.
          '';
        };
      };
      default = { };
      description = ''
        Settings written to /etc/nix/nix.conf, merged with the defaults.
        Lists such as substituters are merged, experimental-features and the other
        defaults (nix-path, store, build-users-group) are replaced by setting them.
      '';
    };
    nixpkgs = lib.mkOption {
      type = with lib.types; nullOr path;
      # same store path as a flake input of the same nixpkgs
      default = builtins.path {
        path = pkgs.path;
        name = "source";
      };
      example = lib.literalExpression "inputs.nixpkgs-unstable";
      description = ''
        What `nixpkgs` is pinned to in /etc/nix/registry.json and the nix-path.

        Defaults to the image's nixpkgs in the image and reuses the image's store paths.
        null sets no pin, leaving it to the booted system.
      '';
    };
    onImageChange = lib.mkOption {
      type = lib.types.enum [
        "attempt-repair"
        "full-reset"
        "do-nothing"
      ];
      default = "full-reset";
      description = ''
        What to do with the upper store in /var/nix when the image's nix store changes
        (bootc upgrade/rollback/switch that contains a different nix store).

        "do-nothing" will leave the upper store as is with no change.
        "attempt-repair" will attempt to repair the store if possible.
        "full-reset" will delete the upper store and re-create it empty.

        Nix does not support a lower store removing packages, it only supports the lower store growing and adding new packages.
        As such "full-reset" is the supported option, as it will ensure that the overlay nix store remains functional.
        See the official documentation for details. https://nix.dev/manual/nix/latest/store/types/experimental-local-overlay-store

        See the systemd service "nix-upper-store-reset" to manually start a wipe of the upper store at will.
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
      {
        # maybe upstream a fix for this?
        # just need to make sure /nix/store/.links is included even when enableFakechroot is set
        assertion = !config.layeredImage.enableFakechroot;
        message = "nix.enable requires layeredImage.enableFakechroot = false, fakechroot drops /nix/store/.links from the image";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # include the nix db from the layeredImage.contents so the nix daemon can see it
    layeredImage.includeNixDB = true;

    # Pick up nix-daemon.service, nix-daemon.socket
    systemd.packages = [ cfg.package ];

    # use nix store selinux labels
    selinux.fileContextSubs = lib.mkIf config.caliga.core.selinux.enable {
      "/var/nix/store/upper" = "/nix/store";
      "/run/nix-lower/nix" = "/nix";
      "/var/nix/var" = "/nix/var";
    };

    systemd.mounts = [
      {
        where = "/run/nix-lower/nix";
        what = "/nix";
        # private mount
        options = "bind,ro,private";
        after = [ "ostree-remount.service" ];
        wants = [ "ostree-remount.service" ];
        unitConfig.DefaultDependencies = false;
      }
      # put all overlay nix dirs where nix expects to find them
      {
        where = "/nix/store";
        what = "overlay";
        type = "overlay";
        options = "lowerdir=/run/nix-lower/nix/store,upperdir=/var/nix/store/upper,workdir=/var/nix/store/work";
        wantedBy = [ "sysinit.target" ];
        before = [ "sysinit.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/run/nix-lower/nix";
        };
      }
      # put all overlay nix dirs where nix expects to find them
      {
        where = "/nix/var";
        what = "/var/nix/var";
        options = "bind";
        wantedBy = [ "sysinit.target" ];
        before = [ "sysinit.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.DefaultDependencies = false;
      }
      # makes sure the image's gcroots are always fresh
      {
        where = "/nix/var/nix/gcroots/docker";
        what = "/run/nix-lower/nix/var/nix/gcroots/docker";
        options = "bind,ro";
        unitConfig.DefaultDependencies = false;
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/nix 0755 root root -"
      "d /var/nix/store/upper 0755 root root -"
      "d /var/nix/store/work 0755 root root -"
      "d /var/nix/var/nix/gcroots 0755 root root -"
      "d /var/nix/var/nix/db 0755 root root -"
      "d /var/nix/var/nix/profiles 0755 root root -"
      "d /var/nix/var/nix/temproots 0755 root root -"
      "d /var/nix/var/nix/userpool 0755 root root -"
      "f /var/nix/lower-store-roots 0644 root root -"
      "d /var/nix/var/nix/daemon-socket 0755 root root -"
      "d /var/nix/var/nix/builds 0755 root root 7d"
      "d /var/nix/var/log/nix 0755 root root -"
    ];

    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/nix-daemon.nix#L280
    systemd.sockets.nix-daemon.wantedBy = [ "sockets.target" ];

    # user overlay store
    systemd.services.nix-daemon = {
      serviceConfig.ExecStart = [
        ""
        "@${cfg.package}/bin/nix-daemon nix-daemon --daemon --option store ${localOverlayStoreUrl}"
      ];
      requires = [ "nix-var-nix-gcroots-docker.mount" ];
      after = [ "nix-var-nix-gcroots-docker.mount" ];
    };

    # same build users and ids as NixOS
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/nix.nix#L94-L111
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix#L387
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix#L738
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

    # by default pin nixpkgs to the nixpkgs the image was built with, so nixpkgs#foo and <nixpkgs> reuse the image's store paths
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/nix-flakes.nix
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/nixpkgs-flake.nix
    environment.etc."nix/registry.json" = lib.mkIf (cfg.nixpkgs != null) {
      text = builtins.toJSON {
        version = 2;
        flakes = [
          {
            from = {
              type = "indirect";
              id = "nixpkgs";
            };
            to = {
              type = "path";
              path = "${cfg.nixpkgs}";
            };
            exact = true;
          }
        ];
      };
    };

    nix.settings = {
      nix-path = lib.mkIf (cfg.nixpkgs != null) (lib.mkDefault "nixpkgs=${cfg.nixpkgs}");
      store = lib.mkDefault "daemon";
      build-users-group = lib.mkDefault "nixbld";
    };

    # same as nixpkgs' nix.conf format, with lib.unique added for lists since we force overlay features
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/pkgs-lib/formats/nix-conf/default.nix#L66-L103
    environment.etc."nix/nix.conf".text =
      let
        value = cfg.settings // {
          # needed for the overlay store, always enabled
          experimental-features = [
            "local-overlay-store"
            "read-only-local-store"
          ]
          ++ cfg.settings.experimental-features;
        };

        mkValueString =
          v:
          if v == null then
            ""
          else if lib.isInt v then
            toString v
          else if lib.isBool v then
            lib.boolToString v
          else if lib.isFloat v then
            lib.strings.floatToString v
          else if lib.isDerivation v then
            toString v
          else if builtins.isPath v then
            toString v
          else if lib.isString v then
            v
          else if lib.isList v then
            toString (lib.unique v)
          else if lib.strings.isConvertibleWithToString v then
            toString v
          else
            abort "The nix conf value: ${lib.generators.toPretty { } v} can not be encoded";

        mkKeyValue = k: v: "${lib.escape [ "=" ] k} = ${mkValueString v}";

        mkKeyValuePairs = attrs: lib.concatStringsSep "\n" (lib.mapAttrsToList mkKeyValue attrs);

        isExtra = key: lib.hasPrefix "extra-" key;
      in
      # workaround for https://github.com/NixOS/nix/issues/9487
      # extra-* settings must come after their non-extra counterpart
      ''
        ${mkKeyValuePairs (lib.filterAttrs (key: _: !(isExtra key)) value)}
        ${mkKeyValuePairs (lib.filterAttrs (key: _: isExtra key) value)}
      '';

    # nix profile installs, the same shell setup the nix installer adds on other distros
    # https://github.com/NixOS/nix/blob/master/scripts/install-multi-user.sh#L889-L911
    environment.etc."profile.d/nix.sh".text = ''
      # Nix
      if [ -e '${cfg.package}/etc/profile.d/nix-daemon.sh' ]; then
        . '${cfg.package}/etc/profile.d/nix-daemon.sh'
      fi
      # End Nix
    '';
    environment.etc."fish/conf.d/nix.fish".text = ''
      # Nix
      if test -e '${cfg.package}/etc/profile.d/nix-daemon.fish'
        . '${cfg.package}/etc/profile.d/nix-daemon.fish'
      end
      # End Nix
    '';

    # the lower store is not supported to change other than growing, handle it changing between images
    # https://nix.dev/manual/nix/latest/store/types/experimental-local-overlay-store
    systemd.services.nix-image-change = lib.mkIf (cfg.onImageChange != "do-nothing") {
      wantedBy = [ "nix-store.mount" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [
        "nix-store.mount"
        "nix-var.mount"
        "nix-var-nix-gcroots-docker.mount"
      ];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = "/run/nix-lower/nix";
      };
      serviceConfig.Type = "oneshot";
      script = ''
        roots=$(LC_ALL=C ls -1 /run/nix-lower/nix/var/nix/gcroots/docker)
        [ "$roots" = "$(cat /var/nix/lower-store-roots)" ] && exit 0
        removed=$(LC_ALL=C comm -13 - /var/nix/lower-store-roots <<<"$roots")
        if [ -z "$removed" ]; then
          echo "saving the image nix store roots, keeping the upper store"
          ${writeStamp}
        else
          echo "image nix store roots changed, handling with ${cfg.onImageChange}"
          ${if cfg.onImageChange == "full-reset" then resetUpper else "touch /run/nix-lower-store-changed"}
        fi
      '';
    };

    # removes upper paths that the new lower store now has, and drops stale paths that nothing uses
    systemd.services.nix-image-change-verify = lib.mkIf (cfg.onImageChange == "attempt-repair") {
      wantedBy = [ "nix-daemon.service" ];
      before = [ "nix-daemon.service" ];
      unitConfig = {
        ConditionPathExists = "/run/nix-lower-store-changed";
        RequiresMountsFor = "/nix/store";
      };
      serviceConfig.Type = "oneshot";
      script = ''
        ${cfg.package}/bin/nix-store --store '${localOverlayStoreUrl}' --optimise

        if ${cfg.package}/bin/nix-store --store '${localOverlayStoreUrl}' --verify; then
          ${writeStamp}
        fi
      '';
    };

    # downloads missing paths that are still in use through the daemon
    systemd.services.nix-image-change-repair = lib.mkIf (cfg.onImageChange == "attempt-repair") {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/run/nix-lower-store-changed";
      serviceConfig = {
        Type = "oneshot";
        PrivateTmp = true;
      };
      script = ''
        set -o pipefail
        log=$(mktemp)
        # --repair will sometimes give up instead of continuing to find the next set of dependancies needed, so we loop it so long as it keeps downloading something...
        # https://github.com/NixOS/nix/issues/9321
        until ${cfg.package}/bin/nix-store --verify --repair 2>&1 | tee "$log"; do
          # nothing downloaded this run, the rest can't be repaired
          grep -q '^copying path' "$log" || exit 1
        done
        ${writeStamp}
      '';
    };

    # manually reset the upper store, `systemctl start nix-upper-store-reset`
    systemd.services.nix-upper-store-reset = {
      path = [ pkgs.util-linux ];
      serviceConfig.Type = "oneshot";
      script = ''
        systemctl stop nix-daemon.socket nix-daemon.service
        umount /nix/var/nix/gcroots/docker || true
        # lazy, don't break what is running
        umount -l /nix/var
        umount -l /nix/store
        ${resetUpper}
        systemctl start 'nix-var.mount' 'nix-store.mount' 'nix-var-nix-gcroots-docker.mount' nix-daemon.socket
      '';
    };
  };
}
