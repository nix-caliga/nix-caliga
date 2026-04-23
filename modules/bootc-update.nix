{
  lib,
  config,
  ...
}:

let
  cfg = config.services.bootc-update;
in
{
  options.services.bootc-update = {
    enable = lib.mkEnableOption "Bootc automatic update service";

    autoReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Reboot after applying an update.";
    };

    schedule = {
      onBootSec = lib.mkOption {
        type = lib.types.str;
        default = "30s";
        description = "Delay after boot before first update check.";
      };

      onUnitActiveSec = lib.mkOption {
        type = lib.types.str;
        default = "1h";
        description = "Interval between update checks.";
      };

      onCalendar = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "daily";
        description = ''
          If set, this overrides onBootSec and onUnitActiveSec.
        '';
      };
    };

    auth = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "ghcr.io" = "dXNlcjpwYXNz";
        "https://index.docker.io/v1/" = "dXNlcjpwYXNz";
      };
      description = ''
        Generate values with: echo -n 'user:pass' | base64
        Builds /etc/ostree/auth.json at image build time.
      '';
    };

    authFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/auth.json";
      description = ''
        Absolute path to a containers auth.json file on the host.
        Symlinked to /etc/ostree/auth.json via tmpfiles at runtime.
        If auth is also set, this takes priority.
        See containers-auth.json(5) for the format.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.caliga.core.systemd.enable;
        message = "services.bootc-update.enable requires caliga.core.systemd.enable = true";
      }
      {
        assertion = cfg.authFile == null || config.caliga.core.tmpfiles.enable;
        message = "services.bootc-update.authFile requires caliga.core.tmpfiles.enable = true";
      }
      {
        assertion = cfg.authFile != null || cfg.auth == { } || config.caliga.core.etc.enable;
        message = "services.bootc-update.auth requires caliga.core.etc.enable = true";
      }
    ];

    # Mask any upstream bootc auto-update units
    systemd.maskedUnits = [
      "bootc-fetch-apply-updates.service"
      "bootc-fetch-apply-updates.timer"
    ];

    systemd.services.bootc-update = {
      description = "Apply bootc updates";
      documentation = [ "man:bootc(8)" ];
      after = [
        "network-online.target"
        "ostree-remount.service"
        "local-fs.target"
      ];
      wants = [ "network-online.target" ];
      unitConfig = {
        ConditionPathExists = "/run/ostree-booted";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/usr/bin/bootc upgrade" + lib.optionalString cfg.autoReboot " --apply" + " --quiet";
        Environment = "PATH=/usr/bin:/usr/sbin";
      };
    };

    systemd.timers.bootc-update = {
      description = "Check for bootc updates periodically";
      wantedBy = [ "timers.target" ];
      timerConfig =
        if cfg.schedule.onCalendar != null then
          {
            OnCalendar = cfg.schedule.onCalendar;
            Persistent = true;
          }
        else
          {
            OnBootSec = cfg.schedule.onBootSec;
            OnUnitActiveSec = cfg.schedule.onUnitActiveSec;
          };
    };

    # authFile - symlink from host path at runtime via tmpfiles
    systemd.tmpfiles.rules = lib.mkIf (cfg.authFile != null) [
      "L+ /etc/ostree/auth.json 0600 root root - ${cfg.authFile}"
    ];

    # auth - build auth.json into the image
    environment.etc = lib.mkIf (cfg.authFile == null && cfg.auth != { }) {
      "ostree/auth.json" = {
        text = builtins.toJSON {
          auths = lib.mapAttrs (_: auth: { inherit auth; }) cfg.auth;
        };
        mode = "0600";
      };
    };
  };
}
