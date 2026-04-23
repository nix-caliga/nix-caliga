# builds systemd services and copies /usr/lib/systemd/system via fakeRootCommands.
# conflict handling follows system-manager
# adds: systemd.defaultUnit option, unit masking, dependency symlinks (wantedBy/requiredBy)
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.systemd;

  enabledUnits = lib.filterAttrs (_: unit: unit.enable) cfg.units;

  mkDepLinks =
    attr: suffix:
    lib.concatStrings (
      lib.mapAttrsToList (
        name: unit:
        lib.concatMapStrings (target: ''
          mkdir -p "$dir"/'${target}.${suffix}'
          ln -sfn '../${name}' "$dir"/'${target}.${suffix}'/
        '') unit.${attr}
      ) enabledUnits
    );

  systemdUnits =
    pkgs.runCommand "systemd-units"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        dir=$out/usr/lib/systemd/system
        mkdir -p "$dir"

        # Copy units from systemd.packages
        ${lib.concatStringsSep "\n" (
          map (package: ''
            if [ -d "${package}/lib/systemd/system" ]; then
              for unit in "${package}/lib/systemd/system"/*; do
                cp -L "$unit" "$dir"/
              done
            fi
          '') cfg.packages
        )}

        # Copy unit files, handling conflicts with drop-in overrides
        for i in ${toString (lib.mapAttrsToList (_: v: v.unit) enabledUnits)}; do
          fn=$(basename $i/*)
          if [ -e "$dir"/$fn ]; then
            if [ "$(readlink -f $i/$fn)" = /dev/null ]; then
              ln -sfn /dev/null "$dir"/$fn
            else
              mkdir -p "$dir"/$fn.d
              cp -L $i/$fn "$dir"/$fn.d/overrides.conf
            fi
          else
            cp -L $i/$fn "$dir"/
          fi
        done

        # Create dependency symlinks
        ${mkDepLinks "wantedBy" "wants"}
        ${mkDepLinks "requiredBy" "requires"}

        # Mask units
        ${lib.concatMapStrings (unit: ''
          ln -sfn /dev/null "$dir"/'${unit}'
        '') cfg.maskedUnits}

        # Set default target
        ${lib.optionalString (cfg.defaultUnit != null) ''
          ln -sfn '${cfg.defaultUnit}' "$dir"/default.target
        ''}
      '';

  hasUnits =
    enabledUnits != { } || cfg.packages != [ ] || cfg.maskedUnits != [ ] || cfg.defaultUnit != null;

in
{
  imports = [
    ./systemd.nix
  ];

  options.systemd.defaultUnit = lib.mkOption {
    default = null;
    type = lib.types.nullOr lib.types.str;
    description = "Default target unit.";
  };

  config = lib.mkIf (config.caliga.core.systemd.enable && hasUnits) {
    assertions =
      let
        enabledUnitNames = lib.attrNames enabledUnits;
        overlap = lib.intersectLists enabledUnitNames cfg.maskedUnits;
      in
      [
        {
          assertion = overlap == [ ];
          message = "units cannot be both defined and masked: ${lib.concatStringsSep ", " overlap}";
        }
      ];

    warnings = lib.optional (!config.caliga.core.selinux.enable && !config.selinux.ignoreWarnings) ''
      caliga.core.systemd.enable is active but caliga.core.selinux.enable is false.
      Systemd units may fail if selinux is enforcing.
      Enable caliga.core.selinux.enable or set selinux.ignoreWarnings = true to silence this warning.
    '';

    layeredImage.enableFakechroot = true;

    layeredImage.fakeRootCommands =
      let
        src = "${systemdUnits}/usr/lib/systemd/system";
      in
      ''
        find ${src} -type d | while read -r d; do
          mkdir -p "usr/lib/systemd/system/''${d#${src}/}"
        done
        find ${src} -type f | while read -r f; do
          install -m 0644 -o 0 -g 0 "$f" "usr/lib/systemd/system/''${f#${src}/}"
        done
        find ${src} -type l | while read -r l; do
          ln -sfn "$(readlink "$l")" "usr/lib/systemd/system/''${l#${src}/}"
        done
      '';
  };
}
